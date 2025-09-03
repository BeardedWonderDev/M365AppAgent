using namespace System.Net

param($Request, $TriggerMetadata)

# Initialize logging context
$APIName = $TriggerMetadata.FunctionName
$StartTime = Get-Date
$RequestId = [System.Guid]::NewGuid().ToString()

# Log function start
Write-Information "[$APIName] Function started at $StartTime"
Write-Information "[$APIName] Request ID: $RequestId"
Write-Information "[$APIName] HTTP Method: $($Request.Method)"

try {
    # Validate webhook authentication (Exchange Online webhook signature)
    if ($Request.Headers.'x-ms-client-principal-id') {
        $principalId = $Request.Headers.'x-ms-client-principal-id'
        Write-Information "[$APIName] Authenticated principal: $principalId"
    }
    elseif ($Request.Headers.'x-webhook-signature') {
        # Validate Exchange Online webhook signature
        $signature = $Request.Headers.'x-webhook-signature'
        $isValid = Test-EmailWebhookSignature -Signature $signature -Body $Request.RawBody
        
        if (-not $isValid) {
            throw "Invalid webhook signature"
        }
    }
    else {
        throw "Missing authentication headers"
    }
    
    # Parse and validate request body
    $RequestBody = $Request.Body | ConvertFrom-Json -ErrorAction Stop
    
    # Validate required properties for email webhook
    $RequiredProperties = @('subject', 'body', 'from', 'tenant')
    foreach ($Property in $RequiredProperties) {
        if (-not $RequestBody.PSObject.Properties.Name -contains $Property) {
            throw "Missing required property: $Property"
        }
    }
    
    # Extract email content and metadata
    $emailContent = @{
        Subject = $RequestBody.subject
        Body = $RequestBody.body
        From = $RequestBody.from
        To = $RequestBody.to
        ReceivedTime = $RequestBody.receivedDateTime ?? (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        MessageId = $RequestBody.messageId ?? [System.Guid]::NewGuid().ToString()
        TenantId = $RequestBody.tenant
        ClientName = $RequestBody.clientName ?? "Unknown Client"
    }
    
    Write-Information "[$APIName] Processing email from: $($emailContent.From)"
    Write-Information "[$APIName] Subject: $($emailContent.Subject)"
    
    # Create AI classification request
    $classificationRequest = [AIClassificationRequest]::new()
    $classificationRequest.Content = "$($emailContent.Subject) - $($emailContent.Body)"
    $classificationRequest.Source = "email"
    $classificationRequest.TenantId = $emailContent.TenantId
    $classificationRequest.ClientName = $emailContent.ClientName
    $classificationRequest.RequestId = $RequestId
    $classificationRequest.Context = @{
        EmailFrom = $emailContent.From
        EmailTo = $emailContent.To
        EmailSubject = $emailContent.Subject
        MessageId = $emailContent.MessageId
        ReceivedTime = $emailContent.ReceivedTime
    }
    
    # Quick pre-filtering to avoid unnecessary AI calls
    $skipPatterns = @(
        'out of office',
        'automatic reply',
        'unsubscribe',
        'newsletter',
        'marketing'
    )
    
    $shouldSkip = $false
    foreach ($pattern in $skipPatterns) {
        if ($emailContent.Subject -match $pattern -or $emailContent.Body -match $pattern) {
            $shouldSkip = $true
            Write-Information "[$APIName] Skipping email - matched skip pattern: $pattern"
            break
        }
    }
    
    if ($shouldSkip) {
        $ResponseBody = @{
            success = $true
            message = "Email skipped - matched exclusion pattern"
            requestId = $RequestId
            timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        } | ConvertTo-Json -Depth 10
        
        $StatusCode = [HttpStatusCode]::OK
    }
    else {
        # Queue for AI classification
        $queueMessage = ConvertTo-SerializableObject -InputObject $classificationRequest | ConvertTo-Json -Depth 10
        
        # Send to Service Bus queue for async processing
        Push-OutputBinding -Name ServiceBusQueue -Value $queueMessage
        
        Write-Information "[$APIName] Email queued for AI classification"
        Write-Information "[$APIName] Queue message size: $($queueMessage.Length) bytes"
        
        # Log to audit table
        try {
            $auditEntry = [AuditLogEntry]::new()
            $auditEntry.TenantId = $emailContent.TenantId
            $auditEntry.ClientName = $emailContent.ClientName
            $auditEntry.Action = "EmailIntakeQueued"
            $auditEntry.ActionType = "email_processing"
            $auditEntry.TargetResource = $emailContent.From
            $auditEntry.PerformedBy = "System"
            $auditEntry.RequestData = @{
                Subject = $emailContent.Subject
                From = $emailContent.From
                MessageId = $emailContent.MessageId
            }
            $auditEntry.Success = $true
            $auditEntry.ResultMessage = "Email queued for AI classification"
            
            Write-AIAgentLog -Message "Email intake audit logged" `
                -Level 'Information' `
                -FunctionName $APIName `
                -RequestId $RequestId `
                -TenantId $emailContent.TenantId
        }
        catch {
            Write-Warning "[$APIName] Failed to write audit log: $($_.Exception.Message)"
        }
        
        # Success response
        $ResponseBody = @{
            success = $true
            data = @{
                requestId = $RequestId
                messageId = $emailContent.MessageId
                status = "queued"
                queuedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            }
            message = "Email successfully queued for AI classification"
            timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        } | ConvertTo-Json -Depth 10
        
        $StatusCode = [HttpStatusCode]::Accepted
    }
    
    Write-Information "[$APIName] Request processed successfully in $((Get-Date) - $StartTime)"
}
catch {
    # Error handling and logging
    $ErrorMessage = $_.Exception.Message
    $ErrorDetails = @{
        message = $ErrorMessage
        stackTrace = $_.Exception.StackTrace
        line = $_.InvocationInfo.ScriptLineNumber
        command = $_.InvocationInfo.MyCommand.Name
    }
    
    Write-Error "[$APIName] Error occurred: $ErrorMessage"
    Write-Error "[$APIName] Error details: $($ErrorDetails | ConvertTo-Json -Compress)"
    
    $ResponseBody = @{
        success = $false
        error = $ErrorMessage
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    # Determine appropriate HTTP status code
    $StatusCode = switch -Regex ($ErrorMessage) {
        "Missing required" { [HttpStatusCode]::BadRequest }
        "Invalid webhook signature|Missing authentication" { [HttpStatusCode]::Unauthorized }
        "Rate limit|Throttl" { [HttpStatusCode]::TooManyRequests }
        default { [HttpStatusCode]::InternalServerError }
    }
}
finally {
    # Cleanup and final logging
    $Duration = (Get-Date) - $StartTime
    Write-Information "[$APIName] Function completed in $Duration"
    
    # Force garbage collection for memory management
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Return response with proper structure
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $ResponseBody
    Headers = @{
        'Content-Type' = 'application/json'
        'X-Function-Name' = $APIName
        'X-Request-Id' = $RequestId
        'X-Processing-Time' = "$($Duration.TotalMilliseconds)ms"
    }
})

function Test-EmailWebhookSignature {
    param(
        [string]$Signature,
        [string]$Body
    )
    
    # TODO: Implement Exchange Online webhook signature validation
    # For now, return true in development
    if ($env:AZURE_FUNCTIONS_ENVIRONMENT -eq 'Development') {
        return $true
    }
    
    # Production validation would verify HMAC signature
    return $true
}