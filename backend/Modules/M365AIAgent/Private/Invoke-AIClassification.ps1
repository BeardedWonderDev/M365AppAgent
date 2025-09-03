function Invoke-AIClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIClassificationRequest]$Request,
        
        [Parameter()]
        [string]$APIName = 'AIClassification',
        
        [Parameter()]
        [bool]$EnableDualValidation = $false  # Claude API to be enabled in future
    )
    
    try {
        Write-AIAgentLog -Message "Starting AI classification for request $($Request.RequestId)" -Level 'Information' -FunctionName $APIName
        
        # Primary classification with OpenAI
        $openAIResult = Invoke-OpenAIClassification -Request $Request
        
        # Secondary validation with Claude (future implementation)
        $claudeResult = $null
        $consensusAchieved = $false
        
        if ($EnableDualValidation -and $env:CLAUDE_API_KEY) {
            try {
                $claudeResult = Invoke-ClaudeValidation -Request $Request -PrimaryResult $openAIResult
                $consensusAchieved = Test-AIConsensus -OpenAIResult $openAIResult -ClaudeResult $claudeResult
            }
            catch {
                Write-AIAgentLog -Message "Claude validation failed, proceeding with OpenAI only" -Level 'Warning' -FunctionName $APIName
            }
        }
        
        # Build final classification result
        $result = Build-ClassificationResult -OpenAIResult $openAIResult -ClaudeResult $claudeResult -ConsensusAchieved $consensusAchieved
        
        Write-AIAgentLog -Message "Classification completed: Action=$($result.Action), Confidence=$($result.Confidence), Risk=$($result.RiskScore)" -Level 'Information' -FunctionName $APIName
        
        return $result
    }
    catch {
        Write-AIAgentLog -Message "AI classification failed" -Level 'Error' -Properties @{
            Error = $_.Exception.Message
            RequestId = $Request.RequestId
            StackTrace = $_.Exception.StackTrace
        } -FunctionName $APIName
        throw
    }
}

function Invoke-OpenAIClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIClassificationRequest]$Request
    )
    
    $apiKey = $env:OPENAI_API_KEY
    if (-not $apiKey) {
        throw "OpenAI API key not found in environment variables"
    }
    
    # Build the classification prompt
    $systemPrompt = @"
You are an AI assistant specialized in classifying Microsoft 365 administrative requests for an MSP environment.
Analyze the request and provide a structured JSON response with:
- action: The specific M365 action to take (e.g., "reset_password", "add_to_group", "create_user")
- confidence: Your confidence level (0.0 to 1.0)
- riskScore: Risk level (0-100, where 0=no risk, 100=critical risk)
- requestType: Category of request (password_reset, group_membership, user_onboarding, etc.)
- parameters: Extracted parameters needed for the action
- affectedUsers: List of affected user emails or UPNs
- affectedGroups: List of affected group names or IDs
- businessImpact: Brief description of business impact
- requiresApproval: Whether human approval is needed (true/false)
"@
    
    $userPrompt = @"
Classify this M365 administrative request:
Content: $($Request.Content)
Source: $($Request.Source)
Tenant: $($Request.TenantId)
Client: $($Request.ClientName)
Context: $($Request.Context | ConvertTo-Json -Compress)
"@
    
    # Prepare OpenAI API request
    $openAIRequest = [OpenAIRequest]::new()
    $openAIRequest.messages = @(
        @{ role = 'system'; content = $systemPrompt }
        @{ role = 'user'; content = $userPrompt }
    )
    
    $headers = @{
        'Authorization' = "Bearer $apiKey"
        'Content-Type' = 'application/json'
    }
    
    $body = $openAIRequest | ConvertTo-Json -Depth 10
    
    # Implement retry logic with exponential backoff
    $maxRetries = 3
    $retryCount = 0
    $baseDelay = 1000  # milliseconds
    
    while ($retryCount -lt $maxRetries) {
        try {
            $response = Invoke-RestMethod -Uri 'https://api.openai.com/v1/chat/completions' `
                -Method POST `
                -Headers $headers `
                -Body $body `
                -ErrorAction Stop
            
            # Parse the AI response
            $aiContent = $response.choices[0].message.content
            $classification = $aiContent | ConvertFrom-Json
            
            # Create and return result
            $result = [AIClassificationResult]::new()
            $result.Action = $classification.action
            $result.Confidence = [double]$classification.confidence
            $result.RiskScore = [int]$classification.riskScore
            $result.RequestType = $classification.requestType
            $result.Parameters = $classification.parameters
            $result.AffectedUsers = $classification.affectedUsers
            $result.AffectedGroups = $classification.affectedGroups
            $result.BusinessImpact = $classification.businessImpact
            $result.RequiresApproval = $classification.requiresApproval
            $result.AIPrimaryModel = 'gpt-4-turbo-preview'
            $result.ProposedChanges = $classification.parameters
            
            return $result
        }
        catch {
            $retryCount++
            
            # Check for rate limiting (429 status)
            if ($_.Exception.Response.StatusCode -eq 429 -and $retryCount -lt $maxRetries) {
                $delay = $baseDelay * [Math]::Pow(2, $retryCount - 1)
                Write-AIAgentLog -Message "OpenAI rate limited, retrying in $($delay)ms" -Level 'Warning'
                Start-Sleep -Milliseconds $delay
                continue
            }
            
            if ($retryCount -ge $maxRetries) {
                throw "OpenAI classification failed after $maxRetries attempts: $($_.Exception.Message)"
            }
            
            throw
        }
    }
}

function Invoke-ClaudeValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIClassificationRequest]$Request,
        
        [Parameter(Mandatory)]
        [AIClassificationResult]$PrimaryResult
    )
    
    # TODO: Implement Claude validation when API access is available
    # This function will provide secondary validation using Claude API
    # For now, return a placeholder that agrees with OpenAI
    
    Write-AIAgentLog -Message "Claude validation not yet implemented - API access pending" -Level 'Information'
    
    # Placeholder implementation
    $result = [AIClassificationResult]::new()
    $result.Action = $PrimaryResult.Action
    $result.Confidence = $PrimaryResult.Confidence * 0.95  # Slightly lower confidence
    $result.RiskScore = $PrimaryResult.RiskScore
    $result.RequestType = $PrimaryResult.RequestType
    $result.RequiresApproval = $PrimaryResult.RequiresApproval
    $result.AISecondaryModel = 'claude-3-sonnet-placeholder'
    
    return $result
}

function Test-AIConsensus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIClassificationResult]$OpenAIResult,
        
        [Parameter()]
        [AIClassificationResult]$ClaudeResult
    )
    
    if (-not $ClaudeResult) {
        return $false
    }
    
    # Check if both models agree on the action and risk assessment
    $actionMatch = $OpenAIResult.Action -eq $ClaudeResult.Action
    $riskMatch = [Math]::Abs($OpenAIResult.RiskScore - $ClaudeResult.RiskScore) -le 20
    $confidenceSufficient = $OpenAIResult.Confidence -gt 0.7 -and $ClaudeResult.Confidence -gt 0.7
    
    return ($actionMatch -and $riskMatch -and $confidenceSufficient)
}

function Build-ClassificationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIClassificationResult]$OpenAIResult,
        
        [Parameter()]
        [AIClassificationResult]$ClaudeResult,
        
        [Parameter()]
        [bool]$ConsensusAchieved = $false
    )
    
    $finalResult = [AIClassificationResult]::new()
    
    if ($ConsensusAchieved -and $ClaudeResult) {
        # Use consensus values
        $finalResult.Action = $OpenAIResult.Action
        $finalResult.Confidence = [Math]::Min($OpenAIResult.Confidence, $ClaudeResult.Confidence)
        $finalResult.RiskScore = [Math]::Max($OpenAIResult.RiskScore, $ClaudeResult.RiskScore)
        $finalResult.ConsensusAchieved = $true
    }
    elseif ($OpenAIResult.Confidence -gt 0.8) {
        # High confidence from primary model
        $finalResult = $OpenAIResult
        $finalResult.ConsensusAchieved = $false
    }
    else {
        # Low confidence or disagreement - default to human review
        $finalResult.Action = 'human_review'
        $finalResult.Confidence = 0.5
        $finalResult.RiskScore = 100  # Max risk for human review
        $finalResult.RequiresApproval = $true
        $finalResult.ConsensusAchieved = $false
        $finalResult.BusinessImpact = 'Requires human review due to low AI confidence or model disagreement'
    }
    
    # Copy common fields
    $finalResult.RequestType = $OpenAIResult.RequestType
    $finalResult.Parameters = $OpenAIResult.Parameters
    $finalResult.AffectedUsers = $OpenAIResult.AffectedUsers
    $finalResult.AffectedGroups = $OpenAIResult.AffectedGroups
    $finalResult.ProposedChanges = $OpenAIResult.ProposedChanges
    $finalResult.AIPrimaryModel = $OpenAIResult.AIPrimaryModel
    $finalResult.AISecondaryModel = $ClaudeResult ? $ClaudeResult.AISecondaryModel : 'none'
    
    # Always require approval for high-risk actions
    if ($finalResult.RiskScore -ge 70) {
        $finalResult.RequiresApproval = $true
    }
    
    return $finalResult
}