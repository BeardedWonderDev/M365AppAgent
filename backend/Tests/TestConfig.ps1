# TestConfig.ps1 - Test configuration and helper functions for M365AIAgent tests
# Supporting infrastructure for comprehensive Pester testing

<#
.SYNOPSIS
    Test configuration and helper functions for M365AIAgent Pester tests
.DESCRIPTION
    Provides shared test data, mock functions, and configuration helpers
    to support comprehensive unit testing of the M365AIAgent module
.NOTES
    Author: AI TenantShield Development Team
    Version: 1.0.0
    Usage: Import this file in test scripts using: . $PSScriptRoot\TestConfig.ps1
#>

# Test Configuration Constants
$script:TestConfig = @{
    APITimeoutSeconds = 30
    MaxRetryAttempts = 3
    TestTenantId = "test-tenant-12345"
    TestClientName = "Test Client Corporation"
    TestUserPrincipalName = "testuser@contoso.com"
    MockDeviceId = "mock-device-12345"
    MockAPIKey = "sk-test-mock-api-key-for-testing"
    
    # Test data paths
    TestDataDirectory = Join-Path $PSScriptRoot "TestData"
    SampleRequestsFile = Join-Path $PSScriptRoot "TestData" "SampleRequests.json"
    ExpectedResponsesFile = Join-Path $PSScriptRoot "TestData" "ExpectedResponses.json"
    
    # Mock API endpoints
    OpenAIEndpoint = "https://api.openai.com/v1/chat/completions"
    ClaudeEndpoint = "https://api.anthropic.com/v1/messages"
    GraphEndpoint = "https://graph.microsoft.com/v1.0"
    KeyVaultEndpoint = "https://test-keyvault.vault.azure.net"
    
    # Performance benchmarks
    MaxClassificationTimeMS = 5000
    MaxAPICallTimeMS = 3000
    MinAccuracyPercentage = 95
}

# Sample Test Data
$script:SampleRequests = @{
    PasswordReset = @{
        Content = "John Smith forgot his password and needs it reset for john.smith@contoso.com"
        Source = "email"
        TenantId = $script:TestConfig.TestTenantId
        ClientName = $script:TestConfig.TestClientName
        Expected = @{
            Action = "reset_password"
            Confidence = 0.95
            RiskScore = 25
            RequestType = "password_reset"
        }
    }
    
    GroupMembership = @{
        Content = "Please add sarah.jones@contoso.com to the Marketing Team security group"
        Source = "ticket"
        TenantId = $script:TestConfig.TestTenantId
        ClientName = $script:TestConfig.TestClientName
        Expected = @{
            Action = "add_to_group"
            Confidence = 0.92
            RiskScore = 45
            RequestType = "group_membership"
        }
    }
    
    HighRiskAdmin = @{
        Content = "Add bob.wilson@contoso.com to Domain Admins group for server maintenance"
        Source = "email"
        TenantId = $script:TestConfig.TestTenantId
        ClientName = $script:TestConfig.TestClientName
        Expected = @{
            Action = "add_to_group"
            Confidence = 0.88
            RiskScore = 95
            RequestType = "security_group_change"
        }
    }
    
    UserOnboarding = @{
        Content = "Create new user account for Michael Johnson, Finance Department, starts Monday"
        Source = "hr_system"
        TenantId = $script:TestConfig.TestTenantId
        ClientName = $script:TestConfig.TestClientName
        Expected = @{
            Action = "create_user"
            Confidence = 0.90
            RiskScore = 35
            RequestType = "user_onboarding"
        }
    }
    
    AmbiguousRequest = @{
        Content = "Help with computer issue"
        Source = "email"
        TenantId = $script:TestConfig.TestTenantId
        ClientName = $script:TestConfig.TestClientName
        Expected = @{
            Action = "human_review"
            Confidence = 0.3
            RiskScore = 100
            RequestType = "unknown"
        }
    }
}

# Mock API Responses
$script:MockAPIResponses = @{
    OpenAI = @{
        PasswordReset = @{
            choices = @(
                @{
                    message = @{
                        content = @'
{
    "action": "reset_password",
    "confidence": 0.95,
    "riskScore": 25,
    "requestType": "password_reset",
    "parameters": {
        "userPrincipalName": "john.smith@contoso.com",
        "forceChangePasswordNextSignIn": true
    },
    "affectedUsers": ["john.smith@contoso.com"],
    "affectedGroups": [],
    "businessImpact": "User will be able to access their account with a new password",
    "requiresApproval": true
}
'@
                    }
                }
            )
            usage = @{
                total_tokens = 145
                prompt_tokens = 95
                completion_tokens = 50
            }
        }
        
        GroupMembership = @{
            choices = @(
                @{
                    message = @{
                        content = @'
{
    "action": "add_to_group",
    "confidence": 0.92,
    "riskScore": 45,
    "requestType": "group_membership",
    "parameters": {
        "userPrincipalName": "sarah.jones@contoso.com",
        "groupName": "Marketing Team",
        "groupId": "marketing-team-guid"
    },
    "affectedUsers": ["sarah.jones@contoso.com"],
    "affectedGroups": ["Marketing Team"],
    "businessImpact": "User will gain access to Marketing Team resources",
    "requiresApproval": true
}
'@
                    }
                }
            )
            usage = @{
                total_tokens = 165
                prompt_tokens = 115
                completion_tokens = 50
            }
        }
    }
    
    GraphAPI = @{
        UserDetails = @{
            '@odata.context' = "https://graph.microsoft.com/v1.0/`$metadata#users/`$entity"
            id = "user-guid-12345"
            userPrincipalName = "john.smith@contoso.com"
            displayName = "John Smith"
            accountEnabled = $true
            mail = "john.smith@contoso.com"
            jobTitle = "Marketing Specialist"
            department = "Marketing"
            createdDateTime = "2023-01-15T10:30:00Z"
        }
        
        GroupDetails = @{
            '@odata.context' = "https://graph.microsoft.com/v1.0/`$metadata#groups/`$entity"
            id = "group-guid-67890"
            displayName = "Marketing Team"
            description = "Marketing department security group"
            groupTypes = @("Unified")
            mailEnabled = $false
            securityEnabled = $true
            visibility = "Private"
        }
        
        PasswordResetSuccess = @{
            '@odata.context' = "https://graph.microsoft.com/v1.0/`$metadata#microsoft.graph.passwordResetResponse"
            success = $true
            message = "Password reset completed successfully"
            temporaryPassword = $null  # Not returned for security
        }
    }
    
    KeyVault = @{
        APIKey = @{
            value = "sk-mock-api-key-from-keyvault"
            attributes = @{
                enabled = $true
                created = [DateTimeOffset]::Now.AddDays(-30)
                updated = [DateTimeOffset]::Now.AddDays(-1)
            }
        }
    }
}

# Mock Error Responses
$script:MockErrorResponses = @{
    RateLimited = @{
        StatusCode = 429
        Headers = @{
            'Retry-After' = '60'
            'X-RateLimit-Remaining' = '0'
        }
        Body = @{
            error = @{
                message = "Rate limit exceeded"
                type = "rate_limit_error"
                code = "rate_limit_exceeded"
            }
        }
    }
    
    Unauthorized = @{
        StatusCode = 401
        Body = @{
            error = @{
                message = "Invalid API key"
                type = "invalid_request_error"
                code = "invalid_api_key"
            }
        }
    }
    
    GraphAPIError = @{
        StatusCode = 404
        Body = @{
            error = @{
                code = "Request_ResourceNotFound"
                message = "Resource not found"
            }
        }
    }
}

# Helper Functions for Tests
function New-TestClassificationRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequestType,
        
        [Parameter()]
        [string]$Content,
        
        [Parameter()]
        [string]$Source = "test",
        
        [Parameter()]
        [string]$TenantId = $script:TestConfig.TestTenantId,
        
        [Parameter()]
        [string]$ClientName = $script:TestConfig.TestClientName
    )
    
    if (-not $Content -and $script:SampleRequests.ContainsKey($RequestType)) {
        $Content = $script:SampleRequests[$RequestType].Content
    }
    
    $Request = [AIClassificationRequest]::new($Content, $Source, $TenantId)
    $Request.ClientName = $ClientName
    
    return $Request
}

function New-TestApprovalRequest {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RequestType = "password_reset",
        
        [Parameter()]
        [int]$RiskScore = 25,
        
        [Parameter()]
        [string]$TenantId = $script:TestConfig.TestTenantId,
        
        [Parameter()]
        [string]$ClientName = $script:TestConfig.TestClientName
    )
    
    $ApprovalRequest = [ApprovalRequest]::new()
    $ApprovalRequest.TenantId = $TenantId
    $ApprovalRequest.ClientName = $ClientName
    $ApprovalRequest.RequestType = $RequestType
    $ApprovalRequest.RiskScore = $RiskScore
    $ApprovalRequest.Description = "Test approval request for $RequestType"
    $ApprovalRequest.Status = "Pending"
    
    return $ApprovalRequest
}

function New-TestBiometricConfirmation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [bool]$Success = $true,
        
        [Parameter()]
        [string]$Method = "Face ID",
        
        [Parameter()]
        [string]$DeviceId = $script:TestConfig.MockDeviceId,
        
        [Parameter()]
        [string]$Platform = "iOS"
    )
    
    $Confirmation = [BiometricConfirmation]::new()
    $Confirmation.Success = $Success
    $Confirmation.Method = $Method
    $Confirmation.DeviceId = $DeviceId
    $Confirmation.Platform = $Platform
    $Confirmation.Hash = New-TestBiometricHash -Method $Method -DeviceId $DeviceId
    
    return $Confirmation
}

function New-TestBiometricHash {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Method = "Face ID",
        
        [Parameter()]
        [string]$DeviceId = $script:TestConfig.MockDeviceId
    )
    
    $Timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $Data = "$Method-$DeviceId-$Timestamp"
    $Hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Data))
    
    return [Convert]::ToHexString($Hash).ToLower()
}

function Assert-AIClassificationAccuracy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$TestResults,
        
        [Parameter()]
        [int]$MinAccuracyPercentage = $script:TestConfig.MinAccuracyPercentage
    )
    
    $TotalTests = $TestResults.Count
    $AccurateTests = ($TestResults | Where-Object { $_.IsAccurate }).Count
    $AccuracyPercentage = [Math]::Round(($AccurateTests / $TotalTests) * 100, 2)
    
    Write-Host "AI Classification Accuracy: $AccuracyPercentage% ($AccurateTests/$TotalTests)" -ForegroundColor Cyan
    
    if ($AccuracyPercentage -lt $MinAccuracyPercentage) {
        throw "AI classification accuracy ($AccuracyPercentage%) is below required threshold ($MinAccuracyPercentage%)"
    }
    
    return @{
        TotalTests = $TotalTests
        AccurateTests = $AccurateTests
        AccuracyPercentage = $AccuracyPercentage
        PassesThreshold = $AccuracyPercentage -ge $MinAccuracyPercentage
    }
}

function Invoke-MockAPICall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Service,
        
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter()]
        [hashtable]$Parameters = @{}
    )
    
    $MockKey = "$Service.$Operation"
    
    if ($script:MockAPIResponses.ContainsKey($Service) -and 
        $script:MockAPIResponses[$Service].ContainsKey($Operation)) {
        return $script:MockAPIResponses[$Service][$Operation]
    }
    
    throw "Mock response not found for $MockKey"
}

function New-MockException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [int]$StatusCode = 500,
        
        [Parameter()]
        [string]$ExceptionType = "System.Net.WebException"
    )
    
    switch ($ExceptionType) {
        "System.Net.WebException" {
            $Exception = [System.Net.WebException]::new($Message)
            
            # Mock HTTP response if status code is provided
            if ($StatusCode -ne 500) {
                $Response = New-Object System.Net.Http.HttpResponseMessage
                $Response.StatusCode = [System.Net.HttpStatusCode]$StatusCode
                $Exception | Add-Member -NotePropertyName Response -NotePropertyValue $Response
            }
            
            return $Exception
        }
        
        "System.UnauthorizedAccessException" {
            return [System.UnauthorizedAccessException]::new($Message)
        }
        
        "System.TimeoutException" {
            return [System.TimeoutException]::new($Message)
        }
        
        default {
            return [System.Exception]::new($Message)
        }
    }
}

function Test-JSONSerialization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $InputObject,
        
        [Parameter()]
        [int]$MaxDepth = 10
    )
    
    try {
        # Test serialization
        $JSON = $InputObject | ConvertTo-Json -Depth $MaxDepth -ErrorAction Stop
        
        # Test deserialization
        $Deserialized = $JSON | ConvertFrom-Json -ErrorAction Stop
        
        return @{
            Success = $true
            JSON = $JSON
            Deserialized = $Deserialized
            Size = $JSON.Length
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            JSON = $null
            Deserialized = $null
            Size = 0
        }
    }
}

function Measure-FunctionPerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [int]$Iterations = 1,
        
        [Parameter()]
        [string]$TestName = "Performance Test"
    )
    
    $Results = @()
    
    for ($i = 0; $i -lt $Iterations; $i++) {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            $Result = & $ScriptBlock
            $Stopwatch.Stop()
            
            $Results += @{
                Iteration = $i + 1
                Success = $true
                ElapsedMS = $Stopwatch.ElapsedMilliseconds
                Result = $Result
                Error = $null
            }
        }
        catch {
            $Stopwatch.Stop()
            
            $Results += @{
                Iteration = $i + 1
                Success = $false
                ElapsedMS = $Stopwatch.ElapsedMilliseconds
                Result = $null
                Error = $_.Exception.Message
            }
        }
    }
    
    # Calculate statistics
    $SuccessfulRuns = $Results | Where-Object { $_.Success }
    $FailedRuns = $Results | Where-Object { -not $_.Success }
    
    if ($SuccessfulRuns.Count -gt 0) {
        $Times = $SuccessfulRuns.ElapsedMS
        $Stats = @{
            TestName = $TestName
            TotalIterations = $Iterations
            SuccessfulRuns = $SuccessfulRuns.Count
            FailedRuns = $FailedRuns.Count
            SuccessRate = [Math]::Round(($SuccessfulRuns.Count / $Iterations) * 100, 2)
            MinTimeMS = ($Times | Measure-Object -Minimum).Minimum
            MaxTimeMS = ($Times | Measure-Object -Maximum).Maximum
            AvgTimeMS = [Math]::Round(($Times | Measure-Object -Average).Average, 2)
            MedianTimeMS = [Math]::Round(($Times | Sort-Object)[[Math]::Floor($Times.Count / 2)], 2)
        }
    }
    else {
        $Stats = @{
            TestName = $TestName
            TotalIterations = $Iterations
            SuccessfulRuns = 0
            FailedRuns = $FailedRuns.Count
            SuccessRate = 0
            MinTimeMS = $null
            MaxTimeMS = $null
            AvgTimeMS = $null
            MedianTimeMS = $null
        }
    }
    
    Write-Host "Performance Test: $TestName" -ForegroundColor Yellow
    Write-Host "  Success Rate: $($Stats.SuccessRate)%" -ForegroundColor $(if ($Stats.SuccessRate -eq 100) { "Green" } else { "Red" })
    if ($Stats.AvgTimeMS) {
        Write-Host "  Average Time: $($Stats.AvgTimeMS)ms" -ForegroundColor Cyan
        Write-Host "  Min/Max Time: $($Stats.MinTimeMS)ms / $($Stats.MaxTimeMS)ms" -ForegroundColor Gray
    }
    
    return @{
        Statistics = $Stats
        DetailedResults = $Results
    }
}

function Initialize-TestEnvironment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SkipModuleImport,
        
        [Parameter()]
        [switch]$SetupMockData
    )
    
    Write-Host "Initializing test environment..." -ForegroundColor Green
    
    # Set test environment variables
    $env:PESTER_TEST_MODE = "true"
    $env:TEST_TENANT_ID = $script:TestConfig.TestTenantId
    $env:TEST_CLIENT_NAME = $script:TestConfig.TestClientName
    
    # Create test data directory if needed
    if (-not (Test-Path $script:TestConfig.TestDataDirectory)) {
        New-Item -ItemType Directory -Path $script:TestConfig.TestDataDirectory -Force | Out-Null
        Write-Host "Created test data directory: $($script:TestConfig.TestDataDirectory)" -ForegroundColor Yellow
    }
    
    # Setup mock data files
    if ($SetupMockData) {
        $script:SampleRequests | ConvertTo-Json -Depth 10 | Out-File $script:TestConfig.SampleRequestsFile -Encoding utf8
        $script:MockAPIResponses | ConvertTo-Json -Depth 10 | Out-File $script:TestConfig.ExpectedResponsesFile -Encoding utf8
        Write-Host "Created mock data files" -ForegroundColor Yellow
    }
    
    Write-Host "Test environment initialized successfully" -ForegroundColor Green
}

function Cleanup-TestEnvironment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$RemoveTestData
    )
    
    Write-Host "Cleaning up test environment..." -ForegroundColor Yellow
    
    # Remove test environment variables
    Remove-Item Env:PESTER_TEST_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:TEST_TENANT_ID -ErrorAction SilentlyContinue
    Remove-Item Env:TEST_CLIENT_NAME -ErrorAction SilentlyContinue
    
    # Remove test data if requested
    if ($RemoveTestData -and (Test-Path $script:TestConfig.TestDataDirectory)) {
        Remove-Item $script:TestConfig.TestDataDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed test data directory" -ForegroundColor Gray
    }
    
    Write-Host "Test environment cleanup completed" -ForegroundColor Green
}

# Export test configuration for use in other test files
Export-ModuleMember -Variable TestConfig, SampleRequests, MockAPIResponses, MockErrorResponses
Export-ModuleMember -Function New-TestClassificationRequest, New-TestApprovalRequest, New-TestBiometricConfirmation,
                             New-TestBiometricHash, Assert-AIClassificationAccuracy, Invoke-MockAPICall,
                             New-MockException, Test-JSONSerialization, Measure-FunctionPerformance,
                             Initialize-TestEnvironment, Cleanup-TestEnvironment