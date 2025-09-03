using namespace System.Net

param($Request, $TriggerMetadata)

# Initialize logging context
$APIName = $TriggerMetadata.FunctionName
$StartTime = Get-Date
$RequestId = [System.Guid]::NewGuid().ToString()

# Log function start
Write-AIAgentLog -Message "[$APIName] Function started" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
Write-AIAgentLog -Message "[$APIName] HTTP Method: $($Request.Method)" -Level 'Information' -FunctionName $APIName -RequestId $RequestId

try {
    # Validate authentication - mobile app must provide JWT bearer token
    $authHeader = $Request.Headers.Authorization
    if (-not $authHeader -or -not $authHeader.StartsWith('Bearer ')) {
        throw [System.UnauthorizedAccessException]::new("Missing or invalid authorization header")
    }
    
    $bearerToken = $authHeader.Substring(7) # Remove "Bearer " prefix
    
    # Validate JWT token (simplified for MVP - would use proper JWT validation in production)
    if ([string]::IsNullOrWhiteSpace($bearerToken)) {
        throw [System.UnauthorizedAccessException]::new("Invalid bearer token")
    }
    
    Write-AIAgentLog -Message "[$APIName] Authentication validated" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    
    # Parse and validate request body
    if (-not $Request.Body) {
        throw [System.ArgumentException]::new("Request body is required")
    }
    
    $RequestBody = $Request.Body | ConvertFrom-Json -ErrorAction Stop
    Write-AIAgentLog -Message "[$APIName] Request body parsed successfully" -Level 'Debug' -FunctionName $APIName -RequestId $RequestId
    
    # Validate required properties for approval submission
    $RequiredProperties = @('RequestId', 'Approved', 'BiometricConfirmation', 'Timestamp')
    foreach ($Property in $RequiredProperties) {
        if (-not $RequestBody.PSObject.Properties.Name -contains $Property) {
            throw [System.ArgumentException]::new("Missing required property: $Property")
        }
    }
    
    # Extract and validate approval submission data
    $approvalSubmission = @{
        RequestId = $RequestBody.RequestId
        Approved = [bool]$RequestBody.Approved
        BiometricConfirmation = $RequestBody.BiometricConfirmation
        Timestamp = $RequestBody.Timestamp
        Notes = $RequestBody.Notes
        ProcessedBy = "MobileApp"
        ProcessingRequestId = $RequestId
    }
    
    Write-AIAgentLog -Message "[$APIName] Processing approval for request: $($approvalSubmission.RequestId)" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    Write-AIAgentLog -Message "[$APIName] Approval decision: $($approvalSubmission.Approved)" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    
    # Retrieve original approval request from storage
    $originalRequest = Get-ApprovalRequest -RequestId $approvalSubmission.RequestId
    if (-not $originalRequest) {
        throw [System.ArgumentException]::new("Original approval request not found: $($approvalSubmission.RequestId)")
    }
    
    # Validate request is still pending and not expired
    if ($originalRequest.Status -ne 'Pending') {
        throw [System.InvalidOperationException]::new("Request $($approvalSubmission.RequestId) is no longer pending (Status: $($originalRequest.Status))")
    }
    
    if ([DateTime]::Parse($originalRequest.ExpiresAt) -lt (Get-Date)) {
        throw [System.InvalidOperationException]::new("Request $($approvalSubmission.RequestId) has expired")
    }
    
    Write-AIAgentLog -Message "[$APIName] Original request validation passed" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    
    # Validate biometric confirmation integrity
    $biometricValid = Test-BiometricConfirmation -BiometricData $approvalSubmission.BiometricConfirmation -RequestId $approvalSubmission.RequestId
    if (-not $biometricValid) {
        throw [System.Security.SecurityException]::new("Biometric confirmation validation failed")
    }
    
    Write-AIAgentLog -Message "[$APIName] Biometric confirmation validated" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    
    # Initialize execution results array
    $executionResults = @()
    $overallSuccess = $true
    $completionMessage = ""
    
    if ($approvalSubmission.Approved) {
        Write-AIAgentLog -Message "[$APIName] Processing APPROVED request - executing actions" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
        
        # Execute approved actions via CIPP integration
        foreach ($action in $originalRequest.ProposedActions) {
            Write-AIAgentLog -Message "[$APIName] Executing action: $($action.ActionType) on $($action.TargetResource)" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
            
            $actionStartTime = Get-Date
            $actionResult = @{
                ActionType = $action.ActionType
                TargetResource = $action.TargetResource
                Success = $false
                ResultMessage = ""
                HttpStatusCode = 0
                ExecutedAt = $actionStartTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                Duration = 0
            }
            
            try {
                # Execute Graph API action via CIPP
                $graphResult = Invoke-CIPPGraphAPIAction -TenantId $originalRequest.TenantId -Action $action
                
                $actionResult.Success = $true
                $actionResult.ResultMessage = "Action executed successfully via CIPP"
                $actionResult.HttpStatusCode = 200
                $actionResult.Duration = ((Get-Date) - $actionStartTime).TotalMilliseconds
                
                Write-AIAgentLog -Message "[$APIName] Action executed successfully: $($action.ActionType)" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
                
                # Log successful action to audit trail
                $auditEntry = [AuditLogEntry]::new()
                $auditEntry.TenantId = $originalRequest.TenantId
                $auditEntry.ClientName = $originalRequest.ClientName
                $auditEntry.Action = $action.ActionType
                $auditEntry.ActionType = "graph_api_execution"
                $auditEntry.TargetResource = $action.TargetResource
                $auditEntry.PerformedBy = "AIAgent"
                $auditEntry.ApprovalRequestId = $approvalSubmission.RequestId
                $auditEntry.BiometricHash = $approvalSubmission.BiometricConfirmation.Hash
                $auditEntry.RequestData = @{
                    GraphAPIEndpoint = $action.GraphAPIEndpoint
                    ProposedState = $action.ProposedState
                    ExecutedAt = $actionResult.ExecutedAt
                    Duration = $actionResult.Duration
                }
                $auditEntry.Success = $true
                $auditEntry.ResultMessage = $actionResult.ResultMessage
                
                Write-AIAgentLog -Message "[$APIName] Audit entry created for successful action" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
            }
            catch {
                $errorMessage = "Failed to execute action: $($_.Exception.Message)"
                $actionResult.Success = $false
                $actionResult.ResultMessage = $errorMessage
                $actionResult.HttpStatusCode = 500
                $actionResult.Duration = ((Get-Date) - $actionStartTime).TotalMilliseconds
                $overallSuccess = $false
                
                Write-AIAgentLog -Message "[$APIName] Action execution failed: $errorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
                
                # Log failed action to audit trail
                $auditEntry = [AuditLogEntry]::new()
                $auditEntry.TenantId = $originalRequest.TenantId
                $auditEntry.ClientName = $originalRequest.ClientName
                $auditEntry.Action = $action.ActionType
                $auditEntry.ActionType = "graph_api_execution"
                $auditEntry.TargetResource = $action.TargetResource
                $auditEntry.PerformedBy = "AIAgent"
                $auditEntry.ApprovalRequestId = $approvalSubmission.RequestId
                $auditEntry.BiometricHash = $approvalSubmission.BiometricConfirmation.Hash
                $auditEntry.RequestData = @{
                    GraphAPIEndpoint = $action.GraphAPIEndpoint
                    ProposedState = $action.ProposedState
                    ExecutedAt = $actionResult.ExecutedAt
                    Duration = $actionResult.Duration
                    Error = $errorMessage
                }
                $auditEntry.Success = $false
                $auditEntry.ResultMessage = $errorMessage
            }
            
            $executionResults += $actionResult
        }
        
        if ($overallSuccess) {
            $completionMessage = "All actions executed successfully"
            $newStatus = "Approved"
        }
        else {
            $completionMessage = "Some actions failed during execution"
            $newStatus = "PartiallyExecuted"
        }
    }
    else {
        Write-AIAgentLog -Message "[$APIName] Processing REJECTED request - no actions to execute" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
        
        $completionMessage = "Request rejected by administrator"
        $newStatus = "Rejected"
        
        # Log rejection to audit trail
        $auditEntry = [AuditLogEntry]::new()
        $auditEntry.TenantId = $originalRequest.TenantId
        $auditEntry.ClientName = $originalRequest.ClientName
        $auditEntry.Action = "ApprovalRejected"
        $auditEntry.ActionType = "approval_decision"
        $auditEntry.TargetResource = $originalRequest.RequestType
        $auditEntry.PerformedBy = "Administrator"
        $auditEntry.ApprovalRequestId = $approvalSubmission.RequestId
        $auditEntry.BiometricHash = $approvalSubmission.BiometricConfirmation.Hash
        $auditEntry.RequestData = @{
            RejectedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            Notes = $approvalSubmission.Notes
        }
        $auditEntry.Success = $true
        $auditEntry.ResultMessage = $completionMessage
        
        Write-AIAgentLog -Message "[$APIName] Rejection audit entry created" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    }
    
    # Update approval request status
    $updateResult = Submit-ApprovalDecision -RequestId $approvalSubmission.RequestId -Decision $newStatus -BiometricConfirmation $approvalSubmission.BiometricConfirmation
    if (-not $updateResult) {
        Write-Warning "[$APIName] Failed to update approval request status"
    }
    
    # Create comprehensive audit log entry for the approval process
    try {
        $processAuditEntry = [AuditLogEntry]::new()
        $processAuditEntry.TenantId = $originalRequest.TenantId
        $processAuditEntry.ClientName = $originalRequest.ClientName
        $processAuditEntry.Action = "ApprovalProcessed"
        $processAuditEntry.ActionType = "approval_processing"
        $processAuditEntry.TargetResource = $originalRequest.RequestType
        $processAuditEntry.PerformedBy = "ApprovalProcessor"
        $processAuditEntry.ApprovalRequestId = $approvalSubmission.RequestId
        $processAuditEntry.BiometricHash = $approvalSubmission.BiometricConfirmation.Hash
        $processAuditEntry.RequestData = @{
            OriginalRequestId = $originalRequest.Id
            ApprovalDecision = $approvalSubmission.Approved
            ProcessedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            ExecutionResults = $executionResults
            BiometricMethod = $approvalSubmission.BiometricConfirmation.Method
            ProcessingDuration = ((Get-Date) - $StartTime).TotalMilliseconds
        }
        $processAuditEntry.Success = $overallSuccess
        $processAuditEntry.ResultMessage = $completionMessage
        
        Write-AIAgentLog -Message "[$APIName] Process audit entry created" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    }
    catch {
        Write-Warning "[$APIName] Failed to create process audit entry: $($_.Exception.Message)"
    }
    
    # Send notification to relevant parties
    try {
        $notificationResult = Send-ApprovalNotification -RequestId $approvalSubmission.RequestId -Status $newStatus -ExecutionResults $executionResults
        Write-AIAgentLog -Message "[$APIName] Notification sent successfully" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    }
    catch {
        Write-Warning "[$APIName] Failed to send notification: $($_.Exception.Message)"
    }
    
    # Prepare success response
    $responseData = [ApprovalResult]@{
        RequestId = $approvalSubmission.RequestId
        Success = $overallSuccess
        Status = $newStatus
        Message = $completionMessage
        ExecutionResults = $executionResults
        CompletedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        AuditLogId = $processAuditEntry.Id ?? "audit-log-failed"
    }
    
    $ResponseBody = @{
        success = $true
        data = $responseData
        message = "Approval processed successfully"
        requestId = $RequestId
        processingTime = ((Get-Date) - $StartTime).TotalMilliseconds
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::OK
    
    Write-AIAgentLog -Message "[$APIName] Approval processing completed successfully" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
}
catch [System.UnauthorizedAccessException] {
    $ErrorMessage = "Unauthorized: $($_.Exception.Message)"
    Write-AIAgentLog -Message "[$APIName] Authorization error: $ErrorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
    
    $ResponseBody = @{
        success = $false
        error = $ErrorMessage
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::Unauthorized
}
catch [System.Security.SecurityException] {
    $ErrorMessage = "Security validation failed: $($_.Exception.Message)"
    Write-AIAgentLog -Message "[$APIName] Security error: $ErrorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
    
    $ResponseBody = @{
        success = $false
        error = $ErrorMessage
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::Forbidden
}
catch [System.ArgumentException] {
    $ErrorMessage = "Invalid request: $($_.Exception.Message)"
    Write-AIAgentLog -Message "[$APIName] Validation error: $ErrorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
    
    $ResponseBody = @{
        success = $false
        error = $ErrorMessage
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::BadRequest
}
catch [System.InvalidOperationException] {
    $ErrorMessage = "Invalid operation: $($_.Exception.Message)"
    Write-AIAgentLog -Message "[$APIName] Operation error: $ErrorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
    
    $ResponseBody = @{
        success = $false
        error = $ErrorMessage
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::Conflict
}
catch {
    # Generic error handling
    $ErrorMessage = $_.Exception.Message
    $ErrorDetails = Get-CippException -Exception $_
    
    Write-AIAgentLog -Message "[$APIName] Unexpected error occurred: $ErrorMessage" -Level 'Error' -FunctionName $APIName -RequestId $RequestId
    Write-AIAgentLog -Message "[$APIName] Error details: $($ErrorDetails | ConvertTo-Json -Compress)" -Level 'Debug' -FunctionName $APIName -RequestId $RequestId
    
    $ResponseBody = @{
        success = $false
        error = "An unexpected error occurred while processing the approval"
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::InternalServerError
}
finally {
    # Cleanup and final logging
    $Duration = (Get-Date) - $StartTime
    Write-AIAgentLog -Message "[$APIName] Function completed in $($Duration.TotalMilliseconds)ms" -Level 'Information' -FunctionName $APIName -RequestId $RequestId
    
    # Force garbage collection for memory management in long-running functions
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Return response with comprehensive headers
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $ResponseBody
    Headers = @{
        'Content-Type' = 'application/json'
        'X-Function-Name' = $APIName
        'X-Request-Id' = $RequestId
        'X-Processing-Time' = "$((Get-Date) - $StartTime | Select-Object -ExpandProperty TotalMilliseconds)ms"
        'X-API-Version' = '1.0'
        'Cache-Control' = 'no-cache, no-store, must-revalidate'
        'Pragma' = 'no-cache'
        'Expires' = '0'
    }
})

# MARK: - Helper Functions

function Test-BiometricConfirmation {
    <#
    .SYNOPSIS
    Validates biometric confirmation data integrity and authenticity
    
    .PARAMETER BiometricData
    Biometric confirmation object from mobile app
    
    .PARAMETER RequestId
    Original request ID for context validation
    
    .RETURNS
    Boolean indicating validation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BiometricData,
        
        [Parameter(Mandatory = $true)]
        [string]$RequestId
    )
    
    try {
        # Validate required biometric data fields
        $requiredFields = @('Success', 'Method', 'Timestamp', 'Hash')
        foreach ($field in $requiredFields) {
            if (-not $BiometricData.ContainsKey($field)) {
                Write-Warning "Missing required biometric field: $field"
                return $false
            }
        }
        
        # Validate biometric authentication was successful
        if (-not [bool]$BiometricData.Success) {
            Write-Warning "Biometric authentication was not successful"
            return $false
        }
        
        # Validate timestamp is recent (within last 5 minutes)
        $biometricTimestamp = [DateTime]::Parse($BiometricData.Timestamp)
        $timeDifference = (Get-Date) - $biometricTimestamp
        if ($timeDifference.TotalMinutes -gt 5) {
            Write-Warning "Biometric timestamp is too old: $($timeDifference.TotalMinutes) minutes"
            return $false
        }
        
        # Validate hash format (should be 64-character hex string for SHA256)
        $hash = $BiometricData.Hash
        if ($hash -notmatch '^[a-fA-F0-9]{64}$') {
            Write-Warning "Invalid biometric hash format"
            return $false
        }
        
        # Additional validation: verify hash contains no obviously fake patterns
        if ($hash -match '(.)\1{10,}' -or $hash -eq '0' * 64 -or $hash -eq 'f' * 64) {
            Write-Warning "Suspicious biometric hash pattern detected"
            return $false
        }
        
        Write-Information "Biometric confirmation validation passed for method: $($BiometricData.Method)"
        return $true
    }
    catch {
        Write-Warning "Error validating biometric confirmation: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-CIPPGraphAPIAction {
    <#
    .SYNOPSIS
    Execute Graph API action via CIPP integration
    
    .PARAMETER TenantId
    Target tenant ID
    
    .PARAMETER Action
    Proposed action object with Graph API details
    
    .RETURNS
    Hashtable with execution result
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Action
    )
    
    try {
        Write-Information "Executing CIPP Graph API action: $($Action.ActionType)"
        Write-Information "Target endpoint: $($Action.GraphAPIEndpoint)"
        Write-Information "Target tenant: $TenantId"
        
        # Determine HTTP method based on action type
        $httpMethod = switch ($Action.ActionType) {
            'password_reset' { 'POST' }
            'group_membership' { 'PATCH' }
            'user_onboarding' { 'POST' }
            'user_offboarding' { 'DELETE' }
            'permission_change' { 'PATCH' }
            'license_assignment' { 'PATCH' }
            default { 'POST' }
        }
        
        # Prepare CIPP Graph API request
        $graphRequest = @{
            Uri = $Action.GraphAPIEndpoint
            Method = $httpMethod
            TenantId = $TenantId
            Headers = @{
                'Content-Type' = 'application/json'
                'ConsistencyLevel' = 'eventual'
            }
        }
        
        # Add body if provided
        if ($Action.GraphAPIBody -and $Action.GraphAPIBody.Count -gt 0) {
            $graphRequest.Body = $Action.GraphAPIBody | ConvertTo-Json -Depth 10
        }
        
        Write-Information "Invoking CIPP Graph request with method: $httpMethod"
        
        # Execute via CIPP's Graph API wrapper with retry logic
        $maxRetries = 3
        $retryCount = 0
        $lastError = $null
        
        do {
            try {
                $result = New-GraphAPIRequest @graphRequest
                
                Write-Information "CIPP Graph API action completed successfully"
                Write-Information "Result type: $($result.GetType().Name)"
                
                return @{
                    Success = $true
                    Result = $result
                    StatusCode = 200
                    Message = "Action executed successfully via CIPP"
                    Retries = $retryCount
                }
            }
            catch {
                $lastError = $_
                $retryCount++
                
                Write-Warning "CIPP Graph API attempt $retryCount failed: $($_.Exception.Message)"
                
                # Check if error is retryable
                if ($_.Exception.Message -match 'throttle|rate limit|429') {
                    if ($retryCount -lt $maxRetries) {
                        $waitTime = [Math]::Pow(2, $retryCount) # Exponential backoff
                        Write-Information "Waiting $waitTime seconds before retry..."
                        Start-Sleep -Seconds $waitTime
                    }
                }
                else {
                    # Non-retryable error, break out of loop
                    break
                }
            }
        } while ($retryCount -lt $maxRetries)
        
        # If we get here, all retries failed
        throw $lastError
    }
    catch {
        Write-Error "Failed to execute CIPP Graph API action: $($_.Exception.Message)"
        
        return @{
            Success = $false
            Result = $null
            StatusCode = 500
            Message = "Failed to execute action: $($_.Exception.Message)"
            Retries = $retryCount
        }
    }
}