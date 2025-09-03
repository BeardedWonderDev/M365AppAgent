# Azure Functions PowerShell Best Practices

## Critical Azure Functions PowerShell Patterns for M365 AI Agent

### Function App Configuration (MANDATORY)

#### host.json Configuration

```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[3.*, 4.0.0)"
  },
  "functionTimeout": "00:10:00",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    },
    "logLevel": {
      "default": "Information"
    }
  },
  "managedDependency": {
    "enabled": true
  },
  "powerShell": {
    "version": "7.4"
  }
}
```

#### requirements.psd1 (CRITICAL Dependencies)

```powershell
@{
    # Azure modules (MANDATORY)
    'Az.Accounts' = '2.*'
    'Az.KeyVault' = '4.*' 
    'Az.Storage' = '5.*'
    
    # Microsoft Graph (MANDATORY for M365 operations)
    'Microsoft.Graph.Authentication' = '1.*'
    'Microsoft.Graph.Users' = '1.*'
    'Microsoft.Graph.Groups' = '1.*'
    
    # CIPP Integration (if extending existing CIPP)
    'CIPPCore' = @{
        version = '1.*'
        source = 'custom'
    }
    
    # Table Storage (MANDATORY for audit logs)
    'AzTable' = '2.*'
    
    # JSON processing
    'PowerShellGet' = '2.*'
}
```

### Profile.ps1 Pattern (CRITICAL for Module Loading)

```powershell
# profile.ps1 - CRITICAL initialization pattern
Write-Information "M365 AI Agent - PowerShell Version: $($PSVersionTable.PSVersion)"

# CRITICAL: Import modules with proper error handling
@('Az.Accounts', 'Az.KeyVault', 'Microsoft.Graph.Authentication', 'M365AIAgent', 'CIPPCore') | ForEach-Object {
    try {
        $Module = $_
        Import-Module -Name $_ -ErrorAction Stop -Force
        Write-Information "Successfully imported module: $Module"
    } catch {
        Write-Error "Failed to import module - $Module : $($_.Exception.Message)"
        # CRITICAL: Don't throw here, log and continue
    }
}

# CRITICAL: Disable Azure context autosave for Functions
try {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Write-Information "Disabled Az context autosave"
} catch {
    Write-Warning "Could not disable Az context autosave: $($_.Exception.Message)"
}

# CRITICAL: Initialize authentication if not from profile
try {
    if (!$env:SetFromProfile) {
        Write-Information "Initializing authentication from Key Vault"
        $Auth = Get-AIAgentAuthentication  # Custom function to get secrets
    }
} catch {
    Write-Error "Could not retrieve authentication: $($_.Exception.Message)"
}

# Set working directory
Set-Location -Path $PSScriptRoot

# CRITICAL: Version tracking for cache invalidation
$CurrentVersion = (Get-Content ".\version_latest.txt" -ErrorAction SilentlyContinue)?.Trim()
if ($CurrentVersion) {
    Write-Information "Function App Version: $CurrentVersion"
    # Update version table for tracking
}
```

### HTTP Trigger Function Pattern (MANDATORY Structure)

#### function.json for HTTP Trigger

```json
{
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "Request",
      "methods": ["post"],
      "route": "ai/classify"
    },
    {
      "type": "http", 
      "direction": "out",
      "name": "Response"
    }
  ]
}
```

#### run.ps1 HTTP Function Template

```powershell
# run.ps1 - CRITICAL HTTP trigger structure
using namespace System.Net

param($Request, $TriggerMetadata)

# CRITICAL: Initialize logging context
$APIName = $TriggerMetadata.FunctionName
$StartTime = Get-Date

# CRITICAL: Input validation and logging
Write-Information "[$APIName] Function started at $StartTime"
Write-Information "[$APIName] HTTP Method: $($Request.Method)"
Write-Information "[$APIName] Request Headers: $($Request.Headers | ConvertTo-Json -Compress)"

try {
    # CRITICAL: Validate required headers
    if (-not $Request.Headers.ContainsKey('x-api-key')) {
        throw "Missing required x-api-key header"
    }
    
    # CRITICAL: Parse and validate request body
    $RequestBody = $Request.Body | ConvertFrom-Json -ErrorAction Stop
    
    # Validate required properties
    $RequiredProperties = @('content', 'source', 'tenantId')
    foreach ($Property in $RequiredProperties) {
        if (-not $RequestBody.PSObject.Properties.Name -contains $Property) {
            throw "Missing required property: $Property"
        }
    }
    
    # CRITICAL: Process the request (main business logic)
    $Result = Invoke-AIClassification -Request $RequestBody -APIName $APIName
    
    # CRITICAL: Success response
    $ResponseBody = @{
        success = $true
        data = $Result
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        requestId = [System.Guid]::NewGuid().ToString()
    } | ConvertTo-Json -Depth 10
    
    $StatusCode = [HttpStatusCode]::OK
    Write-Information "[$APIName] Request processed successfully in $((Get-Date) - $StartTime)"
    
} catch {
    # CRITICAL: Error handling and logging
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
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        requestId = [System.Guid]::NewGuid().ToString()
    } | ConvertTo-Json -Depth 10
    
    # CRITICAL: Determine appropriate HTTP status code
    $StatusCode = switch -Regex ($ErrorMessage) {
        "Missing required" { [HttpStatusCode]::BadRequest }
        "Unauthorized|Authentication" { [HttpStatusCode]::Unauthorized }
        "Rate limit|Throttl" { [HttpStatusCode]::TooManyRequests }
        "Timeout" { [HttpStatusCode]::RequestTimeout }
        default { [HttpStatusCode]::InternalServerError }
    }
}
finally {
    # CRITICAL: Cleanup and final logging
    $Duration = (Get-Date) - $StartTime
    Write-Information "[$APIName] Function completed in $Duration"
    
    # CRITICAL: Force garbage collection for long-running functions
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# CRITICAL: Return response with proper structure
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $ResponseBody
    Headers = @{
        'Content-Type' = 'application/json'
        'X-Function-Name' = $APIName
        'X-Processing-Time' = "$($Duration.TotalMilliseconds)ms"
    }
})
```

### Service Bus Trigger Pattern (For AI Processing)

#### function.json for Service Bus

```json
{
  "bindings": [
    {
      "name": "ServiceBusMessage",
      "type": "serviceBusTrigger", 
      "direction": "in",
      "queueName": "ai-classification-queue",
      "connection": "ServiceBusConnection"
    }
  ]
}
```

#### run.ps1 Service Bus Function

```powershell
# run.ps1 - Service Bus trigger for AI processing
param($ServiceBusMessage, $TriggerMetadata)

$FunctionName = $TriggerMetadata.FunctionName
$StartTime = Get-Date

try {
    Write-Information "[$FunctionName] Processing Service Bus message"
    Write-Information "[$FunctionName] Message ID: $($ServiceBusMessage.MessageId)"
    
    # CRITICAL: Deserialize message
    $RequestData = $ServiceBusMessage | ConvertFrom-Json -ErrorAction Stop
    
    # CRITICAL: Process with AI classification
    $ClassificationResult = Invoke-AIClassification -Request $RequestData
    
    # CRITICAL: Store result and trigger next step
    $StorageResult = Save-ClassificationResult -Result $ClassificationResult
    
    if ($ClassificationResult.RequiresApproval) {
        # CRITICAL: Send to mobile approval queue
        Send-ApprovalRequest -Classification $ClassificationResult
    } else {
        # CRITICAL: Auto-execute low-risk actions
        Invoke-AutoExecution -Classification $ClassificationResult
    }
    
    Write-Information "[$FunctionName] Message processed successfully"
    
} catch {
    # CRITICAL: Handle poison messages
    Write-Error "[$FunctionName] Failed to process message: $($_.Exception.Message)"
    
    # CRITICAL: Implement dead letter logic
    if ($ServiceBusMessage.DeliveryCount -gt 3) {
        Write-Error "[$FunctionName] Message exceeded max delivery attempts, sending to dead letter"
        # Message will automatically go to dead letter queue
    } else {
        # Re-throw to trigger retry
        throw
    }
}
```

### Timer Trigger Pattern (For Cleanup)

```powershell
# Timer trigger for cleanup operations - run.ps1
param($Timer)

$FunctionName = "CleanupTimer"
Write-Information "[$FunctionName] Starting cleanup operations"

try {
    # CRITICAL: Clean up expired approval requests
    $ExpiredRequests = Get-ExpiredApprovalRequests
    foreach ($Request in $ExpiredRequests) {
        Remove-ApprovalRequest -RequestId $Request.Id
        Write-Information "[$FunctionName] Cleaned up expired request: $($Request.Id)"
    }
    
    # CRITICAL: Archive old audit logs
    $OldLogs = Get-AuditLogs -OlderThanDays 365
    if ($OldLogs.Count -gt 0) {
        Export-AuditLogs -Logs $OldLogs -Destination "archive"
        Remove-AuditLogs -Logs $OldLogs
        Write-Information "[$FunctionName] Archived $($OldLogs.Count) old audit logs"
    }
    
    # CRITICAL: Clean up temporary files
    $TempFiles = Get-ChildItem -Path $env:TEMP -Filter "aiagent-*" -File
    $TempFiles | Remove-Item -Force
    Write-Information "[$FunctionName] Cleaned up $($TempFiles.Count) temporary files"
    
} catch {
    Write-Error "[$FunctionName] Cleanup failed: $($_.Exception.Message)"
    # Don't re-throw for timer functions - log and continue
}
```

### Secret Management Pattern (CRITICAL)

```powershell
# Secret management function
function Get-AIAgentAuthentication {
    [CmdletBinding()]
    param()
    
    try {
        # CRITICAL: Use managed identity for Key Vault access
        $KeyVaultName = $env:KEY_VAULT_NAME
        if (-not $KeyVaultName) {
            throw "KEY_VAULT_NAME environment variable not set"
        }
        
        # CRITICAL: Retrieve secrets with error handling
        $Secrets = @{}
        $SecretNames = @('OpenAI-API-Key', 'Claude-API-Key', 'Graph-Client-Secret', 'ServiceBus-Connection')
        
        foreach ($SecretName in $SecretNames) {
            try {
                $Secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction Stop
                $Secrets[$SecretName] = $Secret
                Write-Information "Retrieved secret: $SecretName"
            } catch {
                Write-Error "Failed to retrieve secret $SecretName : $($_.Exception.Message)"
                throw
            }
        }
        
        # CRITICAL: Set environment variables for downstream functions
        $env:OPENAI_API_KEY = $Secrets['OpenAI-API-Key']
        $env:CLAUDE_API_KEY = $Secrets['Claude-API-Key']
        $env:GRAPH_CLIENT_SECRET = $Secrets['Graph-Client-Secret']
        $env:SERVICE_BUS_CONNECTION = $Secrets['ServiceBus-Connection']
        
        return $Secrets
        
    } catch {
        Write-Error "Authentication initialization failed: $($_.Exception.Message)"
        throw
    }
}
```

### Error Handling and Logging Pattern (MANDATORY)

```powershell
# Centralized error handling
function Write-AIAgentLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information',
        
        [Parameter()]
        [hashtable]$Properties = @{},
        
        [Parameter()]
        [string]$FunctionName,
        
        [Parameter()]
        [string]$RequestId
    )
    
    # CRITICAL: Structure log data for Application Insights
    $LogData = @{
        message = $Message
        level = $Level
        functionName = $FunctionName
        requestId = $RequestId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        properties = $Properties
    }
    
    # CRITICAL: Use appropriate PowerShell logging cmdlets
    switch ($Level) {
        'Information' { Write-Information ($LogData | ConvertTo-Json -Compress) -InformationAction Continue }
        'Warning' { Write-Warning ($LogData | ConvertTo-Json -Compress) }
        'Error' { Write-Error ($LogData | ConvertTo-Json -Compress) }
        'Debug' { Write-Debug ($LogData | ConvertTo-Json -Compress) }
    }
    
    # CRITICAL: Also send to custom logging table for audit
    try {
        $LogTable = Get-AzStorageTable -Name 'AIAgentLogs' -Context $StorageContext
        $LogEntity = @{
            PartitionKey = (Get-Date).ToString('yyyy-MM-dd')
            RowKey = "$RequestId-$((Get-Date).Ticks)"
            Message = $Message
            Level = $Level
            FunctionName = $FunctionName
            Properties = ($Properties | ConvertTo-Json -Compress)
        }
        Add-AzStorageTableRow -Table $LogTable -Entity $LogEntity
    } catch {
        # Don't fail the main function if logging fails
        Write-Warning "Failed to write to log table: $($_.Exception.Message)"
    }
}
```

## Critical Gotchas and Requirements

### 1. Memory Management
- ALWAYS disable Az context autosave: `Disable-AzContextAutosave -Scope Process`
- Use `[System.GC]::Collect()` after processing large datasets
- Clear variables in long-running functions: `Remove-Variable -Name LargeObject -Force`

### 2. Module Loading
- Import modules in profile.ps1 with proper error handling
- Use `-Force` parameter to ensure fresh module loading
- Don't throw exceptions during module import in profile.ps1

### 3. Authentication
- Use managed identity for Azure resources
- Store all secrets in Azure Key Vault
- Never log authentication tokens or secrets

### 4. Error Handling
- Always use try/catch blocks for external API calls
- Return appropriate HTTP status codes
- Implement retry logic with exponential backoff

### 5. Performance
- Set appropriate function timeout in host.json
- Use async patterns where possible
- Implement connection pooling for database operations

### 6. Security
- Validate all inputs before processing
- Use function-level authentication (`"authLevel": "function"`)
- Implement rate limiting for public endpoints
- Never expose sensitive data in logs or responses

## Implementation Checklist

- [ ] host.json configured with PowerShell 7.4 and appropriate timeouts
- [ ] requirements.psd1 includes all necessary Azure and Graph modules  
- [ ] profile.ps1 implements proper module loading with error handling
- [ ] All functions use structured error handling with appropriate HTTP status codes
- [ ] Authentication uses managed identity and Key Vault for secrets
- [ ] Logging includes structured data for Application Insights
- [ ] Memory management includes garbage collection for large operations
- [ ] Input validation implemented for all function parameters
- [ ] Retry logic implemented for external API calls
- [ ] Dead letter queue handling for Service Bus triggers