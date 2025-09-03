# CIPP-API Integration Patterns

## Critical CIPP Patterns for M365 AI Agent Implementation

### Authentication Pattern (MANDATORY)

CIPP uses a specific OAuth2 refresh token pattern that MUST be followed exactly:

```powershell
# CRITICAL: This exact pattern from CIPP profile.ps1
$AuthBody = @{
    client_id = $ENV:ApplicationId
    client_secret = $ENV:ApplicationSecret
    scope = 'https://graph.microsoft.com/.default'
    grant_type = 'refresh_token'
    refresh_token = $ENV:RefreshToken
}

$AuthParams = @{
    URI = "https://login.microsoftonline.com/$($ENV:TenantId)/oauth2/v2.0/token"
    Body = $AuthBody
    Method = 'POST'
    ContentType = 'application/x-www-form-urlencoded'
    ErrorAction = 'Stop'  # CRITICAL: Must use Stop for proper error handling
}

$AccessToken = (Invoke-RestMethod @AuthParams).access_token
$GraphHeader = @{
    Authorization = "Bearer $AccessToken"
}
```

**GOTCHA**: Always use `ErrorAction = 'Stop'` for authentication calls to ensure failures are caught properly.

### Graph API Request Pattern

```powershell
# CRITICAL: CIPP splatting pattern for Graph requests
$GraphParams = @{
    URI = 'https://graph.microsoft.com/v1.0/users'
    Headers = $GraphHeader
    Method = 'GET'
    ErrorAction = 'Stop'
}

try {
    $Result = Invoke-RestMethod @GraphParams
    # Process result
} catch {
    Write-LogMessage -message "Graph API call failed" -LogData (Get-CippException -Exception $_) -Sev 'Error'
    throw
}
```

### Module Loading Pattern (From CIPP profile.ps1)

```powershell
# CRITICAL: Module loading with proper error handling
@('CIPPCore', 'CippExtensions', 'Az.KeyVault', 'Az.Accounts', 'AzBobbyTables') | ForEach-Object {
    try {
        $Module = $_
        Import-Module -Name $_ -ErrorAction Stop
    } catch {
        Write-LogMessage -message "Failed to import module - $Module" -LogData (Get-CippException -Exception $_) -Sev 'debug'
        $_.Exception.Message
    }
}

# CRITICAL: Disable Az context autosave for Azure Functions
try {
    Disable-AzContextAutosave -Scope Process | Out-Null
} catch {}
```

### Logging Pattern (MANDATORY)

```powershell
# CRITICAL: CIPP logging pattern that must be used
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message "Processing request" -Sev "Info" -tenant $TenantFilter

# For errors:
Write-LogMessage -message "Operation failed" -LogData (Get-CippException -Exception $_) -Sev "Error" -tenant $TenantFilter
```

**GOTCHA**: Always include tenant context in logging for multi-tenant scenarios.

### Azure Functions Structure (From CIPP)

```json
// function.json for HTTP trigger
{
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger", 
      "direction": "in",
      "name": "Request",
      "methods": ["get", "post"]
    },
    {
      "type": "http",
      "direction": "out", 
      "name": "Response"
    }
  ]
}
```

```powershell
# run.ps1 structure pattern
using namespace System.Net

param($Request, $TriggerMetadata)

# Input validation
$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

try {
    # Main processing logic here
    
    $body = "Success message"
    $StatusCode = [HttpStatusCode]::OK
} catch {
    Write-LogMessage -message "Error occurred" -LogData (Get-CippException -Exception $_) -Sev 'Error'
    $body = "Error: $($_.Exception.Message)"
    $StatusCode = [HttpStatusCode]::BadRequest
}

# Return response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $body
})
```

### Error Handling Pattern

```powershell
# CRITICAL: CIPP exception handling pattern
function Get-CippException {
    param($Exception)
    
    return @{
        Message = $Exception.Exception.Message
        StackTrace = $Exception.Exception.StackTrace
        Line = $Exception.InvocationInfo.ScriptLineNumber
        Command = $Exception.InvocationInfo.MyCommand
    }
}

# Usage in try/catch blocks:
try {
    # Operation
} catch {
    Write-LogMessage -message "Operation failed" -LogData (Get-CippException -Exception $_) -Sev "Error"
    throw  # Re-throw to maintain error flow
}
```

### Key Vault Integration Pattern

```powershell
# CRITICAL: Key Vault access pattern from CIPP
try {
    $Auth = Get-CIPPAuthentication  # CIPP's Key Vault function
} catch {
    Write-LogMessage -message 'Could not retrieve keys from Keyvault' -LogData (Get-CippException -Exception $_) -Sev 'debug'
}
```

## Implementation Requirements

1. **MUST** use exact CIPP authentication pattern
2. **MUST** use CIPP logging functions (Write-LogMessage)
3. **MUST** use CIPP error handling (Get-CippException)
4. **MUST** disable Az context autosave in Azure Functions
5. **MUST** use splatting for REST API calls
6. **MUST** include proper tenant context in all operations

## Security Considerations

- All secrets MUST be stored in Azure Key Vault
- Authentication tokens MUST NOT be logged
- All Graph API calls MUST use proper error handling
- Multi-tenant isolation MUST be maintained through proper tenant filtering