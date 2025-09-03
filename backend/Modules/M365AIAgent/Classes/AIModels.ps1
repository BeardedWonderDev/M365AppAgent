# AIModels.ps1 - PowerShell classes for AI request/response models
# These classes ensure JSON serialization compatibility with the mobile app

class AIClassificationRequest {
    [string]$Content
    [string]$Source
    [string]$TenantId
    [string]$ClientName
    [hashtable]$Context
    [datetime]$ReceivedAt
    [string]$RequestId
    
    AIClassificationRequest() {
        $this.RequestId = [System.Guid]::NewGuid().ToString()
        $this.ReceivedAt = Get-Date
        $this.Context = @{}
    }
    
    AIClassificationRequest([string]$content, [string]$source, [string]$tenantId) {
        $this.Content = $content
        $this.Source = $source
        $this.TenantId = $tenantId
        $this.RequestId = [System.Guid]::NewGuid().ToString()
        $this.ReceivedAt = Get-Date
        $this.Context = @{}
    }
}

class AIClassificationResult {
    [string]$Action
    [double]$Confidence
    [int]$RiskScore
    [hashtable]$Parameters
    [bool]$RequiresApproval
    [string]$BusinessImpact
    [string]$RequestType
    [string[]]$AffectedUsers
    [string[]]$AffectedGroups
    [hashtable]$ProposedChanges
    [string]$AIPrimaryModel
    [string]$AISecondaryModel
    [bool]$ConsensusAchieved
    
    AIClassificationResult() {
        $this.Parameters = @{}
        $this.ProposedChanges = @{}
        $this.RequiresApproval = $true
        $this.ConsensusAchieved = $false
    }
}

class ApprovalRequest {
    [string]$Id
    [string]$TenantId
    [string]$ClientName
    [string]$RequestType
    [string]$Description
    [int]$RiskScore
    [ProposedAction[]]$ProposedActions
    [RequestContext]$Context
    [datetime]$ExpiresAt
    [datetime]$CreatedAt
    [string]$Status
    [string]$CreatedBy
    [string]$ApprovedBy
    [datetime]$ApprovedAt
    [BiometricConfirmation]$BiometricConfirmation
    
    ApprovalRequest() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.CreatedAt = Get-Date
        $this.ExpiresAt = (Get-Date).AddMinutes(30)
        $this.Status = 'Pending'
        $this.ProposedActions = @()
    }
}

class ProposedAction {
    [string]$ActionType
    [string]$TargetResource
    [hashtable]$CurrentState
    [hashtable]$ProposedState
    [string]$GraphAPIEndpoint
    [hashtable]$GraphAPIBody
    [string]$Description
    [string]$Impact
    
    ProposedAction() {
        $this.CurrentState = @{}
        $this.ProposedState = @{}
        $this.GraphAPIBody = @{}
    }
}

class RequestContext {
    [string]$OriginalRequestContent
    [string]$RequestSource
    [string]$ClientName
    [string]$TenantId
    [string]$RequestorEmail
    [string]$RequestorName
    [hashtable]$CurrentState
    [hashtable]$AdditionalMetadata
    [datetime]$DetectedAt
    
    RequestContext() {
        $this.CurrentState = @{}
        $this.AdditionalMetadata = @{}
        $this.DetectedAt = Get-Date
    }
}

class BiometricConfirmation {
    [bool]$Success
    [string]$Method
    [datetime]$Timestamp
    [string]$Hash
    [string]$DeviceId
    [string]$Platform
    
    BiometricConfirmation() {
        $this.Timestamp = Get-Date
    }
}

class ApprovalResult {
    [string]$RequestId
    [bool]$Success
    [string]$Status
    [string]$Message
    [ExecutionResult[]]$ExecutionResults
    [datetime]$CompletedAt
    [string]$AuditLogId
    
    ApprovalResult() {
        $this.ExecutionResults = @()
        $this.CompletedAt = Get-Date
    }
}

class ExecutionResult {
    [string]$ActionType
    [bool]$Success
    [string]$TargetResource
    [string]$ResultMessage
    [hashtable]$ResultData
    [string]$GraphAPIResponse
    [int]$HttpStatusCode
    [datetime]$ExecutedAt
    
    ExecutionResult() {
        $this.ResultData = @{}
        $this.ExecutedAt = Get-Date
    }
}

class AuditLogEntry {
    [string]$Id
    [string]$TenantId
    [string]$ClientName
    [string]$Action
    [string]$ActionType
    [string]$TargetResource
    [string]$PerformedBy
    [string]$ApprovedBy
    [BiometricConfirmation]$BiometricConfirmation
    [datetime]$Timestamp
    [bool]$Success
    [string]$ResultMessage
    [hashtable]$RequestData
    [hashtable]$ResponseData
    [int]$RiskScore
    [string]$IPAddress
    [string]$UserAgent
    
    AuditLogEntry() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Timestamp = Get-Date
        $this.RequestData = @{}
        $this.ResponseData = @{}
    }
}

class OpenAIRequest {
    [string]$model
    [hashtable[]]$messages
    [double]$temperature
    [int]$max_tokens
    [hashtable]$response_format
    
    OpenAIRequest() {
        $this.model = 'gpt-4-turbo-preview'
        $this.temperature = 0.3
        $this.max_tokens = 1000
        $this.messages = @()
        $this.response_format = @{ type = 'json_object' }
    }
}

class ClaudeRequest {
    [string]$model
    [int]$max_tokens
    [hashtable[]]$messages
    [double]$temperature
    
    ClaudeRequest() {
        $this.model = 'claude-3-sonnet-20240229'
        $this.temperature = 0.3
        $this.max_tokens = 1000
        $this.messages = @()
    }
}

class RiskLevel : System.Enum {
    [int]Low = 0
    [int]Medium = 30
    [int]High = 70
    [int]Critical = 90
}

class RequestType : System.Enum {
    [string]PasswordReset = 'password_reset'
    [string]GroupMembership = 'group_membership'
    [string]UserOnboarding = 'user_onboarding'
    [string]UserOffboarding = 'user_offboarding'
    [string]PermissionChange = 'permission_change'
    [string]LicenseAssignment = 'license_assignment'
    [string]SecurityGroupChange = 'security_group_change'
    [string]ConditionalAccessChange = 'conditional_access_change'
}

class ApprovalStatus : System.Enum {
    [string]Pending = 'pending'
    [string]Approved = 'approved'
    [string]Rejected = 'rejected'
    [string]Expired = 'expired'
    [string]AutoApproved = 'auto_approved'
    [string]AutoRejected = 'auto_rejected'
}

# Helper function to convert class to hashtable for JSON serialization
function ConvertTo-SerializableObject {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )
    
    $result = @{}
    $properties = $InputObject.PSObject.Properties
    
    foreach ($property in $properties) {
        if ($null -ne $property.Value) {
            if ($property.Value -is [datetime]) {
                $result[$property.Name] = $property.Value.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            }
            elseif ($property.Value -is [Array]) {
                $result[$property.Name] = @($property.Value | ForEach-Object {
                    if ($_.GetType().BaseType.Name -eq 'Object') {
                        ConvertTo-SerializableObject -InputObject $_
                    } else {
                        $_
                    }
                })
            }
            elseif ($property.Value.GetType().BaseType.Name -eq 'Object' -and $property.Value -isnot [string] -and $property.Value -isnot [hashtable]) {
                $result[$property.Name] = ConvertTo-SerializableObject -InputObject $property.Value
            }
            else {
                $result[$property.Name] = $property.Value
            }
        }
    }
    
    return $result
}