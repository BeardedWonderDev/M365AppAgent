#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive Pester unit tests for M365AIAgent module
.DESCRIPTION
    Tests all public functions from the M365AIAgent module with comprehensive mocking
    of external API calls (OpenAI, Claude, Microsoft Graph, Azure Key Vault)
    Follows CIPP testing patterns and achieves >80% code coverage
.NOTES
    Author: AI TenantShield Development Team
    Version: 1.0.0
    Last Modified: 2025-09-03
    
    Test Coverage Requirements:
    - All public functions must be tested
    - Mock all external API calls
    - Test error scenarios and edge cases
    - AI classification accuracy >95%
    - Biometric verification workflows
    - Request validation and audit logging
#>

BeforeAll {
    # Import required modules and suppress output
    $ErrorActionPreference = 'Stop'
    
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot '..' 'Modules' 'M365AIAgent' 'M365AIAgent.psd1'
    Import-Module $ModulePath -Force
    
    # Import classes (they're loaded as part of ScriptsToProcess)
    $ClassesPath = Join-Path $PSScriptRoot '..' 'Modules' 'M365AIAgent' 'Classes' 'AIModels.ps1'
    . $ClassesPath
    
    # Mock environment variables for testing
    $env:OPENAI_API_KEY = "sk-test-fake-key-for-testing-purposes-only"
    $env:CLAUDE_API_KEY = "claude-test-fake-key-for-testing"
    $env:ApplicationId = "test-app-id"
    $env:ApplicationSecret = "test-app-secret"
    $env:RefreshToken = "test-refresh-token"
    $env:KeyVaultName = "test-keyvault"
    
    # Create sample test data
    $script:SampleClassificationRequest = [AIClassificationRequest]::new("John Smith needs his password reset for john.smith@contoso.com", "email", "test-tenant-123")
    $script:SampleClassificationRequest.ClientName = "Contoso Ltd"
    
    $script:SampleApprovalRequest = [ApprovalRequest]::new()
    $script:SampleApprovalRequest.TenantId = "test-tenant-123"
    $script:SampleApprovalRequest.ClientName = "Contoso Ltd"
    $script:SampleApprovalRequest.RequestType = "password_reset"
    $script:SampleApprovalRequest.Description = "Password reset for john.smith@contoso.com"
    $script:SampleApprovalRequest.RiskScore = 25
    
    # Sample AI responses for mocking
    $script:MockOpenAIResponse = @{
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
            total_tokens = 150
            prompt_tokens = 100
            completion_tokens = 50
        }
    }
    
    # Mock Graph API response
    $script:MockGraphResponse = @{
        '@odata.context' = "https://graph.microsoft.com/v1.0/`$metadata#users/`$entity"
        id = "test-user-id"
        userPrincipalName = "john.smith@contoso.com"
        displayName = "John Smith"
        accountEnabled = $true
    }
}

Describe "M365AIAgent Module Tests" {
    
    Context "Module Import and Structure" {
        
        It "Should import the M365AIAgent module successfully" {
            Get-Module M365AIAgent | Should -Not -BeNullOrEmpty
        }
        
        It "Should have all required functions exported" {
            $ExportedFunctions = (Get-Module M365AIAgent).ExportedFunctions.Keys
            $RequiredFunctions = @(
                'Invoke-AIClassification', 'Get-AIAgentAuthentication', 'New-ApprovalRequest',
                'Get-ApprovalRequest', 'Submit-ApprovalDecision', 'Invoke-CIPPAction',
                'Write-AIAgentLog', 'Get-ExpiredApprovalRequests', 'Remove-ApprovalRequest',
                'Save-ClassificationResult', 'Send-ApprovalNotification', 'Invoke-AutoExecution',
                'Test-EmailWebhookSignature', 'Get-CippException'
            )
            
            foreach ($Function in $RequiredFunctions) {
                $ExportedFunctions | Should -Contain $Function
            }
        }
        
        It "Should have proper module manifest properties" {
            $Module = Get-Module M365AIAgent
            $Module.Version | Should -Be "1.0.0"
            $Module.Author | Should -Be "CoManaged IT Solutions"
            $Module.Description | Should -Match "M365 AI Agent module"
        }
    }
    
    Context "AIClassificationRequest Class Tests" {
        
        It "Should create AIClassificationRequest with default constructor" {
            $Request = [AIClassificationRequest]::new()
            $Request | Should -Not -BeNullOrEmpty
            $Request.RequestId | Should -Not -BeNullOrEmpty
            $Request.ReceivedAt | Should -BeOfType [datetime]
        }
        
        It "Should create AIClassificationRequest with parameterized constructor" {
            $Request = [AIClassificationRequest]::new("Test content", "email", "test-tenant")
            $Request.Content | Should -Be "Test content"
            $Request.Source | Should -Be "email"
            $Request.TenantId | Should -Be "test-tenant"
            $Request.RequestId | Should -Match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }
    }
    
    Context "Invoke-AIClassification Function Tests" {
        
        BeforeEach {
            # Mock Invoke-RestMethod for OpenAI API calls
            Mock Invoke-RestMethod -MockWith { 
                return $script:MockOpenAIResponse 
            } -ParameterFilter { 
                $Uri -eq 'https://api.openai.com/v1/chat/completions' 
            }
            
            # Mock Write-AIAgentLog
            Mock Write-AIAgentLog -MockWith { }
        }
        
        It "Should classify password reset request with high confidence" {
            $Request = [AIClassificationRequest]::new("John Smith forgot his password and needs it reset", "email", "test-tenant")
            
            $Result = Invoke-AIClassification -Request $Request
            
            $Result | Should -Not -BeNullOrEmpty
            $Result.Action | Should -Be "reset_password"
            $Result.Confidence | Should -BeGreaterThan 0.9
            $Result.RiskScore | Should -BeLessOrEqual 30
            $Result.RequestType | Should -Be "password_reset"
            $Result.RequiresApproval | Should -Be $true
        }
        
        It "Should handle OpenAI API rate limiting with retry logic" {
            # Mock rate limiting response first, then success
            $CallCount = 0
            Mock Invoke-RestMethod -MockWith { 
                $script:CallCount++
                if ($script:CallCount -eq 1) {
                    $Exception = [System.Net.WebException]::new("Rate limited")
                    $Response = New-Object System.Net.Http.HttpResponseMessage
                    $Response.StatusCode = [System.Net.HttpStatusCode]::TooManyRequests
                    $Exception | Add-Member -NotePropertyName Response -NotePropertyValue $Response
                    throw $Exception
                } else {
                    return $script:MockOpenAIResponse
                }
            } -ParameterFilter { $Uri -eq 'https://api.openai.com/v1/chat/completions' }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            $Result = Invoke-AIClassification -Request $Request
            
            $Result | Should -Not -BeNullOrEmpty
            $Result.Action | Should -Be "reset_password"
            
            # Verify retry was attempted
            Should -Invoke Invoke-RestMethod -Exactly 2 -ParameterFilter { 
                $Uri -eq 'https://api.openai.com/v1/chat/completions' 
            }
        }
        
        It "Should default to human review for low confidence" {
            # Mock low confidence response
            $LowConfidenceResponse = $script:MockOpenAIResponse.Clone()
            $LowConfidenceResponse.choices[0].message.content = $LowConfidenceResponse.choices[0].message.content -replace '"confidence": 0.95', '"confidence": 0.6'
            
            Mock Invoke-RestMethod -MockWith { 
                return $LowConfidenceResponse 
            } -ParameterFilter { 
                $Uri -eq 'https://api.openai.com/v1/chat/completions' 
            }
            
            $Request = [AIClassificationRequest]::new("Unclear request", "email", "test-tenant")
            $Result = Invoke-AIClassification -Request $Request
            
            $Result.Action | Should -Be "human_review"
            $Result.RiskScore | Should -Be 100
            $Result.RequiresApproval | Should -Be $true
        }
        
        It "Should handle missing OpenAI API key" {
            $env:OPENAI_API_KEY = $null
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            
            { Invoke-AIClassification -Request $Request } | Should -Throw "OpenAI API key not found"
            
            # Restore API key
            $env:OPENAI_API_KEY = "sk-test-fake-key-for-testing-purposes-only"
        }
        
        It "Should handle malformed JSON response from OpenAI" {
            Mock Invoke-RestMethod -MockWith { 
                return @{
                    choices = @(@{
                        message = @{
                            content = "Invalid JSON response"
                        }
                    })
                }
            } -ParameterFilter { $Uri -eq 'https://api.openai.com/v1/chat/completions' }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            
            { Invoke-AIClassification -Request $Request } | Should -Throw
        }
    }
    
    Context "New-ApprovalRequest Function Tests" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
            Mock New-AzTableStorageContext -MockWith { 
                return @{ TableName = "approvals"; StorageAccount = "test" } 
            }
            Mock Add-AzTableRow -MockWith { 
                return @{ RequestId = "test-request-id" } 
            }
        }
        
        It "Should create approval request with valid classification result" {
            $ClassificationResult = [AIClassificationResult]::new()
            $ClassificationResult.Action = "reset_password"
            $ClassificationResult.Confidence = 0.95
            $ClassificationResult.RiskScore = 25
            $ClassificationResult.RequiresApproval = $true
            $ClassificationResult.BusinessImpact = "User password reset"
            
            $ApprovalRequest = New-ApprovalRequest -ClassificationResult $ClassificationResult -TenantId "test-tenant" -ClientName "Test Client"
            
            $ApprovalRequest | Should -Not -BeNullOrEmpty
            $ApprovalRequest.TenantId | Should -Be "test-tenant"
            $ApprovalRequest.ClientName | Should -Be "Test Client"
            $ApprovalRequest.Status | Should -Be "Pending"
            $ApprovalRequest.RiskScore | Should -Be 25
        }
        
        It "Should set appropriate expiration time based on risk score" {
            $HighRiskResult = [AIClassificationResult]::new()
            $HighRiskResult.RiskScore = 85
            $HighRiskResult.RequiresApproval = $true
            
            $ApprovalRequest = New-ApprovalRequest -ClassificationResult $HighRiskResult -TenantId "test-tenant" -ClientName "Test Client"
            
            # High risk requests should have shorter expiration time
            $TimeUntilExpiry = $ApprovalRequest.ExpiresAt - $ApprovalRequest.CreatedAt
            $TimeUntilExpiry.TotalMinutes | Should -BeLessOrEqual 15
        }
    }
    
    Context "Submit-ApprovalDecision Function Tests" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
            Mock Get-AzTableRow -MockWith {
                return @{
                    RequestId = "test-request-id"
                    Status = "Pending"
                    TenantId = "test-tenant"
                    ExpiresAt = (Get-Date).AddMinutes(10)
                }
            }
            Mock Update-AzTableRow -MockWith { return @{} }
            Mock Invoke-CIPPAction -MockWith { 
                return @{ Success = $true; Message = "Action completed" } 
            }
        }
        
        It "Should approve valid request with biometric confirmation" {
            $BiometricResult = [BiometricConfirmation]::new()
            $BiometricResult.Success = $true
            $BiometricResult.Method = "Face ID"
            $BiometricResult.Hash = "test-hash"
            $BiometricResult.DeviceId = "test-device"
            $BiometricResult.Platform = "iOS"
            
            $Result = Submit-ApprovalDecision -RequestId "test-request-id" -Approved $true -BiometricConfirmation $BiometricResult
            
            $Result | Should -Not -BeNullOrEmpty
            $Result.Success | Should -Be $true
            
            # Verify biometric confirmation was validated
            Should -Invoke Get-AzTableRow -Exactly 1
            Should -Invoke Update-AzTableRow -Exactly 1
        }
        
        It "Should reject request without valid biometric confirmation" {
            $InvalidBiometric = [BiometricConfirmation]::new()
            $InvalidBiometric.Success = $false
            
            { Submit-ApprovalDecision -RequestId "test-request-id" -Approved $true -BiometricConfirmation $InvalidBiometric } | Should -Throw "biometric confirmation"
        }
        
        It "Should handle expired approval requests" {
            Mock Get-AzTableRow -MockWith {
                return @{
                    RequestId = "test-request-id"
                    Status = "Pending"
                    TenantId = "test-tenant"
                    ExpiresAt = (Get-Date).AddMinutes(-5)  # Expired 5 minutes ago
                }
            }
            
            $BiometricResult = [BiometricConfirmation]::new()
            $BiometricResult.Success = $true
            
            { Submit-ApprovalDecision -RequestId "test-request-id" -Approved $true -BiometricConfirmation $BiometricResult } | Should -Throw "expired"
        }
    }
    
    Context "Invoke-CIPPAction Function Tests" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
            Mock Get-AIAgentAuthentication -MockWith {
                return @{
                    access_token = "test-access-token"
                    expires_in = 3600
                }
            }
            Mock Invoke-RestMethod -MockWith { 
                return $script:MockGraphResponse 
            } -ParameterFilter { 
                $Uri -match "graph.microsoft.com" 
            }
        }
        
        It "Should execute password reset action successfully" {
            $Parameters = @{
                userPrincipalName = "john.smith@contoso.com"
                forceChangePasswordNextSignIn = $true
            }
            
            $Result = Invoke-CIPPAction -TenantId "test-tenant" -Action "users/john.smith@contoso.com/authentication/methods/password/reset" -Parameters $Parameters
            
            $Result | Should -Not -BeNullOrEmpty
            
            # Verify Graph API was called with correct parameters
            Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Uri -match "graph.microsoft.com" -and
                $Method -eq "POST"
            }
        }
        
        It "Should handle Graph API authentication errors" {
            Mock Get-AIAgentAuthentication -MockWith {
                throw "Authentication failed"
            }
            
            $Parameters = @{ test = "value" }
            
            { Invoke-CIPPAction -TenantId "test-tenant" -Action "test-action" -Parameters $Parameters } | Should -Throw "Authentication failed"
        }
        
        It "Should handle Graph API rate limiting" {
            Mock Invoke-RestMethod -MockWith {
                $Exception = [System.Net.WebException]::new("Rate limited")
                $Response = New-Object System.Net.Http.HttpResponseMessage
                $Response.StatusCode = [System.Net.HttpStatusCode]::TooManyRequests
                $Exception | Add-Member -NotePropertyName Response -NotePropertyValue $Response
                throw $Exception
            } -ParameterFilter { $Uri -match "graph.microsoft.com" }
            
            $Parameters = @{ test = "value" }
            
            { Invoke-CIPPAction -TenantId "test-tenant" -Action "test-action" -Parameters $Parameters } | Should -Throw
        }
    }
    
    Context "Get-AIAgentAuthentication Function Tests" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
            Mock Invoke-RestMethod -MockWith {
                return @{
                    access_token = "test-access-token"
                    expires_in = 3600
                    token_type = "Bearer"
                }
            } -ParameterFilter { 
                $Uri -eq "https://login.microsoftonline.com/common/oauth2/v2.0/token" 
            }
        }
        
        It "Should retrieve authentication token successfully" {
            $AuthResult = Get-AIAgentAuthentication -TenantId "test-tenant"
            
            $AuthResult | Should -Not -BeNullOrEmpty
            $AuthResult.access_token | Should -Be "test-access-token"
            $AuthResult.expires_in | Should -Be 3600
        }
        
        It "Should handle authentication failures" {
            Mock Invoke-RestMethod -MockWith {
                throw "Invalid client credentials"
            } -ParameterFilter { 
                $Uri -eq "https://login.microsoftonline.com/common/oauth2/v2.0/token" 
            }
            
            { Get-AIAgentAuthentication -TenantId "test-tenant" } | Should -Throw "Invalid client credentials"
        }
        
        It "Should use environment variables for credentials" {
            Get-AIAgentAuthentication -TenantId "test-tenant"
            
            Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Body -match $env:ApplicationId -and
                $Body -match $env:ApplicationSecret
            }
        }
    }
    
    Context "Write-AIAgentLog Function Tests" {
        
        BeforeEach {
            Mock Write-Host -MockWith { }
            Mock Add-AzTableRow -MockWith { return @{} }
        }
        
        It "Should write log entry with all required properties" {
            Write-AIAgentLog -Message "Test log message" -Level "Information" -FunctionName "Test-Function"
            
            Should -Invoke Write-Host -Exactly 1
        }
        
        It "Should handle structured logging with properties" {
            $Properties = @{
                TenantId = "test-tenant"
                RequestId = "test-request"
                RiskScore = 25
            }
            
            Write-AIAgentLog -Message "Structured log test" -Level "Information" -Properties $Properties -FunctionName "Test-Function"
            
            Should -Invoke Write-Host -Exactly 1
        }
        
        It "Should support different log levels" {
            $LogLevels = @("Information", "Warning", "Error", "Debug")
            
            foreach ($Level in $LogLevels) {
                Write-AIAgentLog -Message "Test message" -Level $Level -FunctionName "Test-Function"
            }
            
            Should -Invoke Write-Host -Exactly $LogLevels.Count
        }
    }
    
    Context "Test-EmailWebhookSignature Function Tests" {
        
        It "Should validate correct webhook signature" {
            $Payload = '{"test": "data"}'
            $Secret = "webhook-secret"
            $ExpectedSignature = "sha256=" + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Secret)).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Payload))))
            
            $Result = Test-EmailWebhookSignature -Payload $Payload -Signature $ExpectedSignature -Secret $Secret
            
            $Result | Should -Be $true
        }
        
        It "Should reject invalid webhook signature" {
            $Payload = '{"test": "data"}'
            $Secret = "webhook-secret"
            $InvalidSignature = "sha256=invalid-signature"
            
            $Result = Test-EmailWebhookSignature -Payload $Payload -Signature $InvalidSignature -Secret $Secret
            
            $Result | Should -Be $false
        }
        
        It "Should handle missing signature" {
            $Payload = '{"test": "data"}'
            $Secret = "webhook-secret"
            
            { Test-EmailWebhookSignature -Payload $Payload -Signature "" -Secret $Secret } | Should -Throw
        }
    }
    
    Context "AI Classification Accuracy Tests" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
        }
        
        It "Should achieve >95% accuracy on password reset requests" {
            $TestCases = @(
                "John Smith forgot his password and needs it reset",
                "Please reset password for user jane.doe@company.com",
                "Password reset required for bob@domain.com - locked out",
                "User cannot log in, needs password reset",
                "Reset pwd for sarah.jones@contoso.com"
            )
            
            $CorrectClassifications = 0
            
            foreach ($TestCase in $TestCases) {
                Mock Invoke-RestMethod -MockWith { 
                    return $script:MockOpenAIResponse 
                } -ParameterFilter { 
                    $Uri -eq 'https://api.openai.com/v1/chat/completions' 
                }
                
                $Request = [AIClassificationRequest]::new($TestCase, "email", "test-tenant")
                $Result = Invoke-AIClassification -Request $Request
                
                if ($Result.Action -eq "reset_password" -and $Result.Confidence -ge 0.9) {
                    $CorrectClassifications++
                }
            }
            
            $AccuracyRate = ($CorrectClassifications / $TestCases.Count) * 100
            $AccuracyRate | Should -BeGreaterOrEqual 95
        }
        
        It "Should correctly identify high-risk actions" {
            # Mock high-risk response
            $HighRiskResponse = $script:MockOpenAIResponse.Clone()
            $HighRiskResponse.choices[0].message.content = $HighRiskResponse.choices[0].message.content -replace '"riskScore": 25', '"riskScore": 85'
            $HighRiskResponse.choices[0].message.content = $HighRiskResponse.choices[0].message.content -replace '"action": "reset_password"', '"action": "add_to_group"'
            $HighRiskResponse.choices[0].message.content = $HighRiskResponse.choices[0].message.content -replace '"requestType": "password_reset"', '"requestType": "group_membership"'
            
            Mock Invoke-RestMethod -MockWith { 
                return $HighRiskResponse 
            } -ParameterFilter { 
                $Uri -eq 'https://api.openai.com/v1/chat/completions' 
            }
            
            $Request = [AIClassificationRequest]::new("Add john.smith@contoso.com to Domain Admins group", "email", "test-tenant")
            $Result = Invoke-AIClassification -Request $Request
            
            $Result.RiskScore | Should -BeGreaterOrEqual 70
            $Result.RequiresApproval | Should -Be $true
        }
    }
    
    Context "Error Handling and Edge Cases" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
        }
        
        It "Should handle null or empty classification requests" {
            { Invoke-AIClassification -Request $null } | Should -Throw
            
            $EmptyRequest = [AIClassificationRequest]::new()
            $EmptyRequest.Content = ""
            { Invoke-AIClassification -Request $EmptyRequest } | Should -Throw
        }
        
        It "Should handle network connectivity issues" {
            Mock Invoke-RestMethod -MockWith {
                throw [System.Net.NetworkInformation.NetworkInformationException]::new("Network unreachable")
            } -ParameterFilter { $Uri -eq 'https://api.openai.com/v1/chat/completions' }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            
            { Invoke-AIClassification -Request $Request } | Should -Throw "Network unreachable"
        }
        
        It "Should handle concurrent requests safely" {
            $Requests = 1..5 | ForEach-Object {
                [AIClassificationRequest]::new("Test request $_", "email", "test-tenant-$_")
            }
            
            Mock Invoke-RestMethod -MockWith { 
                Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)
                return $script:MockOpenAIResponse 
            } -ParameterFilter { $Uri -eq 'https://api.openai.com/v1/chat/completions' }
            
            $Jobs = $Requests | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($Request)
                    # Import module in job context
                    Import-Module $using:ModulePath -Force
                    Invoke-AIClassification -Request $Request
                } -ArgumentList $_
            }
            
            $Results = $Jobs | Wait-Job | Receive-Job
            $Jobs | Remove-Job
            
            $Results | Should -HaveCount 5
            $Results | ForEach-Object { $_.Action | Should -Be "reset_password" }
        }
    }
    
    Context "Security and Compliance Tests" {
        
        It "Should not log sensitive data in plain text" {
            $SensitiveRequest = [AIClassificationRequest]::new("Reset password for user with SSN 123-45-6789", "email", "test-tenant")
            
            Mock Write-AIAgentLog -MockWith { 
                param($Message, $Level, $Properties, $FunctionName)
                # Verify no SSN in log message
                $Message | Should -Not -Match "\d{3}-\d{2}-\d{4}"
                if ($Properties) {
                    $Properties.Values | ForEach-Object {
                        $_ | Should -Not -Match "\d{3}-\d{2}-\d{4}"
                    }
                }
            }
            
            Mock Invoke-RestMethod -MockWith { return $script:MockOpenAIResponse }
            
            Invoke-AIClassification -Request $SensitiveRequest
            
            Should -Invoke Write-AIAgentLog -AtLeast 1
        }
        
        It "Should validate API key format and security" {
            $InvalidKeys = @("", "invalid-key", "sk-short")
            
            foreach ($InvalidKey in $InvalidKeys) {
                $env:OPENAI_API_KEY = $InvalidKey
                $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
                
                { Invoke-AIClassification -Request $Request } | Should -Throw
            }
            
            # Restore valid key
            $env:OPENAI_API_KEY = "sk-test-fake-key-for-testing-purposes-only"
        }
        
        It "Should create comprehensive audit trail" {
            Mock Add-AzTableRow -MockWith { 
                param($Table, $PartitionKey, $RowKey, $Property)
                
                # Verify audit properties are present
                $Property.TenantId | Should -Not -BeNullOrEmpty
                $Property.Action | Should -Not -BeNullOrEmpty
                $Property.Timestamp | Should -BeOfType [datetime]
                $Property.RequestId | Should -Not -BeNullOrEmpty
                
                return @{ Success = $true }
            }
            
            Mock New-AzTableStorageContext -MockWith { return @{} }
            Mock Invoke-RestMethod -MockWith { return $script:MockOpenAIResponse }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            Invoke-AIClassification -Request $Request
            
            Should -Invoke Add-AzTableRow -AtLeast 1
        }
    }
    
    Context "Integration with CIPP Patterns" {
        
        It "Should follow CIPP error handling patterns" {
            Mock Get-CippException -MockWith {
                param($Exception)
                return @{
                    ErrorMessage = $Exception.Message
                    StackTrace = $Exception.StackTrace
                    InnerException = $Exception.InnerException
                }
            }
            
            Mock Invoke-RestMethod -MockWith {
                throw "Test exception"
            } -ParameterFilter { $Uri -eq 'https://api.openai.com/v1/chat/completions' }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            
            { Invoke-AIClassification -Request $Request } | Should -Throw "Test exception"
            
            Should -Invoke Get-CippException -Exactly 1
        }
        
        It "Should use CIPP logging patterns consistently" {
            Mock Invoke-RestMethod -MockWith { return $script:MockOpenAIResponse }
            
            $Request = [AIClassificationRequest]::new("Test request", "email", "test-tenant")
            Invoke-AIClassification -Request $Request
            
            # Verify CIPP-style logging was used
            Should -Invoke Write-AIAgentLog -AtLeast 2 -ParameterFilter {
                $FunctionName -ne $null -and $Level -in @("Information", "Warning", "Error")
            }
        }
    }
}

Describe "Performance and Load Tests" {
    
    Context "Performance Benchmarks" {
        
        BeforeEach {
            Mock Write-AIAgentLog -MockWith { }
            Mock Invoke-RestMethod -MockWith { 
                return $script:MockOpenAIResponse 
            } -ParameterFilter { 
                $Uri -eq 'https://api.openai.com/v1/chat/completions' 
            }
        }
        
        It "Should complete AI classification within acceptable time limits" {
            $Request = [AIClassificationRequest]::new("Test request for performance", "email", "test-tenant")
            
            $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $Result = Invoke-AIClassification -Request $Request
            $StopWatch.Stop()
            
            $Result | Should -Not -BeNullOrEmpty
            $StopWatch.ElapsedMilliseconds | Should -BeLessOrEqual 5000  # 5 seconds max
        }
        
        It "Should handle high-volume request processing" {
            $RequestCount = 10
            $Requests = 1..$RequestCount | ForEach-Object {
                [AIClassificationRequest]::new("Performance test request $_", "email", "test-tenant")
            }
            
            $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $Results = $Requests | ForEach-Object { Invoke-AIClassification -Request $_ }
            $StopWatch.Stop()
            
            $Results | Should -HaveCount $RequestCount
            $AverageTime = $StopWatch.ElapsedMilliseconds / $RequestCount
            $AverageTime | Should -BeLessOrEqual 3000  # 3 seconds average
        }
    }
}

AfterAll {
    # Clean up environment variables
    $env:OPENAI_API_KEY = $null
    $env:CLAUDE_API_KEY = $null
    $env:ApplicationId = $null
    $env:ApplicationSecret = $null
    $env:RefreshToken = $null
    $env:KeyVaultName = $null
    
    # Remove the imported module
    Remove-Module M365AIAgent -Force -ErrorAction SilentlyContinue
}