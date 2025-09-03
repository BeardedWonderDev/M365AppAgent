---
name: "M365 AI Agent MVP Implementation - AI-Powered MSP Automation Platform"
description: |
  Complete MVP implementation of M365 AI Agent system featuring:
  - AI-powered request detection and classification (OpenAI GPT-4 + Claude dual validation)
  - PowerShell/Azure Functions backend with CIPP-API integration
  - Skip Fuse mobile app with biometric approval workflows
  - Security-first design with multi-level approval gates
  - Comprehensive audit trails and compliance logging
---

## Goal

**Feature Goal**: Implement a fully functional M365 AI Agent MVP that automatically detects, classifies, and processes M365 administrative requests through secure mobile approval workflows

**Deliverable**: Complete end-to-end system including:
- AI detection engine (PowerShell/Azure Functions)
- Mobile approval app (Skip Fuse - iOS & Android)
- CIPP-API integration module
- Email/ticket monitoring services
- Comprehensive testing and validation

**Success Definition**: System successfully processes password reset and group membership requests from email detection through mobile approval to execution, with <2 minute approval time and >95% accuracy

## User Persona

**Target User**: Senior MSP Technician (Sarah persona from user journeys)

**Use Case**: After-hours M365 administrative request processing while maintaining security and audit compliance

**User Journey**: 
1. Client emails password reset request → AI detects and classifies → Push notification to mobile → Biometric approval → Automated execution → Client notification
2. High-risk group membership request → Dual AI validation → Multi-level approval workflow → Secure execution with audit trail

**Pain Points Addressed**: 
- Eliminates manual request interpretation and processing
- Enables secure after-hours approvals without compromising security
- Provides complete audit trails for compliance
- Reduces human error through AI classification and automated execution

## Why

- **Business Value**: 70% reduction in manual M365 administration time, enabling MSPs to serve more clients efficiently
- **Integration**: Leverages existing CIPP-API infrastructure while adding AI-powered automation layer
- **Security Enhancement**: Multi-level biometric approvals with comprehensive audit trails exceed traditional manual processes
- **Market Opportunity**: First-to-market AI-native MSP solution targeting $50M+ market opportunity

## What

Complete AI-powered M365 tenant management system that bridges email/ticketing systems with secure mobile approval workflows.

### Success Criteria

- [ ] AI classification accuracy >95% for password reset and group membership requests
- [ ] Mobile approval workflow completes in <2 minutes end-to-end
- [ ] System processes requests 24/7 with >99.9% uptime
- [ ] Complete audit trail for all administrative actions with biometric confirmation
- [ ] CIPP-API integration maintains existing security and compliance standards
- [ ] Dual-model AI validation provides security risk assessment for all requests
- [ ] Multi-level approval workflows for high-risk administrative changes

## All Needed Context

### Context Completeness Check

_This PRP is designed for a greenfield implementation of the M365 AI Agent system. All implementation details, patterns, and external resources are provided to enable one-pass implementation success._

### Documentation & References

```yaml
# MUST READ - AI Integration Patterns
- url: https://platform.openai.com/docs/api-reference/chat
  why: OpenAI GPT-4 chat completion API for request classification and risk assessment
  critical: Proper error handling, rate limiting, and authentication patterns for enterprise use

- url: https://docs.anthropic.com/en/api/messages
  why: Claude Messages API for secondary validation and consensus with OpenAI
  critical: Request format differences from OpenAI, different authentication headers

- url: https://docs.microsoft.com/en-us/graph/api/overview
  why: Microsoft Graph API integration patterns for M365 tenant management
  critical: Authentication flow, permission scopes, and rate limiting considerations

# MUST READ - PowerShell/Azure Functions Patterns  
- url: https://docs.cipp.app/dev-documentation/cipp-dev-guide/development-tips
  why: CIPP-API development patterns, authentication, and Graph API integration
  critical: |
    CIPP uses specific patterns for:
    - OAuth2 refresh token authentication 
    - Graph API request splatting with error handling
    - Structured logging with Write-LogMessage
    - Module organization and dependency management

- file: PRPs/ai_docs/cipp_patterns.md
  why: Detailed CIPP-API integration patterns extracted from research
  pattern: PowerShell module structure, authentication flows, error handling
  gotcha: CIPP uses specific authentication patterns that must be followed exactly

# MUST READ - Skip Fuse Mobile Development
- url: https://skip.tools/docs/
  why: Skip Fuse framework documentation for cross-platform mobile development  
  critical: SwiftUI to Jetpack Compose transpilation patterns and limitations

- url: https://source.skip.tools/skip-firebase.git
  why: Skip Firebase integration examples showing cross-platform patterns
  critical: How to structure modules for iOS/Android compatibility in Skip

- file: PRPs/ai_docs/skip_fuse_patterns.md
  why: Skip Fuse mobile app architecture patterns and biometric integration
  pattern: SwiftUI structure, biometric authentication, push notifications
  gotcha: Biometric authentication requires platform-specific implementations

# MUST READ - Azure Functions Architecture
- url: https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell
  why: PowerShell Azure Functions development best practices and patterns
  critical: Module loading, environment variables, and performance considerations

- file: PRPs/ai_docs/azure_functions_powershell.md
  why: Azure Functions PowerShell best practices from CIPP research
  pattern: Function structure, dependency management, error handling
  gotcha: PowerShell module loading in Azure Functions has specific requirements
```

### Current Codebase Tree (Greenfield Project)

```bash
M365AppAgent/
├── docs/                          # Project documentation
│   ├── M365-AI-Agent-Project-Brief.md
│   ├── Technical-Specifications.md
│   └── User-Journey-Maps.md
├── PRPs/                          # Product requirement prompts
│   ├── templates/
│   └── ai_docs/                   # AI documentation (to be created)
└── CLAUDE.md                      # Development guidelines
```

### Desired Codebase Tree with Files to be Added

```bash
M365AppAgent/
├── backend/                       # PowerShell/Azure Functions backend
│   ├── Functions/
│   │   ├── EmailIntake/
│   │   │   ├── run.ps1            # HTTP trigger for email webhooks
│   │   │   └── function.json      # Function configuration
│   │   ├── TicketIntake/
│   │   │   ├── run.ps1            # HTTP trigger for ticket webhooks  
│   │   │   └── function.json      # Function configuration
│   │   ├── AIClassification/
│   │   │   ├── run.ps1            # Service Bus trigger for AI processing
│   │   │   └── function.json      # Function configuration
│   │   ├── ApprovalProcessor/
│   │   │   ├── run.ps1            # HTTP trigger for mobile approvals
│   │   │   └── function.json      # Function configuration
│   │   └── ActionExecutor/
│   │       ├── run.ps1            # Queue trigger for executing actions
│   │       └── function.json      # Function configuration
│   ├── Modules/
│   │   ├── M365AIAgent/
│   │   │   ├── M365AIAgent.psd1   # Module manifest
│   │   │   ├── Public/            # Public functions
│   │   │   ├── Private/           # Private helper functions
│   │   │   └── Classes/           # PowerShell classes
│   │   └── CIPPIntegration/
│   │       ├── CIPPIntegration.psd1
│   │       └── Public/
│   ├── Tests/                     # Pester tests
│   ├── host.json                  # Function app configuration
│   ├── requirements.psd1          # PowerShell dependencies
│   └── profile.ps1                # Function app profile
├── mobile/                        # Skip Fuse mobile application
│   ├── Sources/
│   │   └── M365AgentApp/
│   │       ├── M365AgentApp.swift # App entry point
│   │       ├── Models/            # Data models
│   │       ├── Views/             # SwiftUI views
│   │       ├── Services/          # Business logic services
│   │       └── Skip/              # Skip configuration
│   ├── Tests/                     # XCTest unit tests
│   └── Package.swift              # Swift package manifest
├── infrastructure/                # Azure deployment templates
│   ├── bicep/                     # Bicep templates
│   └── scripts/                   # Deployment scripts
└── docs/                          # Documentation (existing)
```

### Known Gotchas & Library Quirks

```yaml
# CRITICAL: CIPP Authentication Pattern
# CIPP uses specific OAuth2 refresh token pattern that must be followed exactly
authentication_pattern: |
  $AuthBody = @{
    client_id = $ENV:ApplicationId
    client_secret = $ENV:ApplicationSecret  
    scope = 'https://graph.microsoft.com/.default'
    grant_type = 'refresh_token'
    refresh_token = $ENV:RefreshToken
  }
  # Must use ErrorAction 'Stop' for proper error handling

# CRITICAL: PowerShell Module Loading in Azure Functions
module_loading: |
  # Profile.ps1 must import modules with specific error handling
  @('CIPPCore', 'M365AIAgent') | ForEach-Object {
    try {
      Import-Module -Name $_ -ErrorAction Stop
    } catch {
      Write-LogMessage -message "Failed to import module - $_" -Sev 'debug'
    }
  }

# CRITICAL: Skip Fuse Biometric Authentication  
biometric_auth: |
  # Must use LocalAuthentication framework on iOS
  # Different implementation required for Android through Skip transpilation
  # Face ID requires specific usage description in Info.plist

# CRITICAL: AI API Rate Limiting
rate_limiting: |
  # OpenAI: 10,000 requests/minute for GPT-4
  # Claude: 50,000 requests/minute  
  # Must implement exponential backoff and circuit breaker patterns

# CRITICAL: Azure Functions PowerShell Memory Management
memory_management: |
  # Must disable Az context autosave: Disable-AzContextAutosave -Scope Process
  # Clear variables in long-running functions to prevent memory leaks
  # Use [System.GC]::Collect() for large data processing
```

## Implementation Blueprint

### Data Models and Structure

Create type-safe data models ensuring consistency across PowerShell backend and Swift mobile app.

```powershell
# PowerShell Classes (backend/Modules/M365AIAgent/Classes/)
class AIClassificationRequest {
    [string]$Content
    [string]$Source  
    [string]$TenantId
    [hashtable]$Context
}

class AIClassificationResult {
    [string]$Action
    [double]$Confidence
    [int]$RiskScore
    [hashtable]$Parameters
    [bool]$RequiresApproval
    [string]$BusinessImpact
}

class ApprovalRequest {
    [string]$Id
    [string]$TenantId
    [string]$RequestType
    [string]$Description
    [int]$RiskScore
    [hashtable[]]$ProposedActions
    [datetime]$ExpiresAt
    [datetime]$CreatedAt
}
```

```swift
// Swift Models (mobile/Sources/M365AgentApp/Models/)
struct ApprovalRequest: Codable, Identifiable {
    let id: UUID
    let tenantId: String
    let requestType: RequestType
    let description: String
    let riskScore: Int
    let proposedActions: [ProposedAction]
    let context: RequestContext
    let expiresAt: Date
    let createdAt: Date
}

enum RequestType: String, Codable, CaseIterable {
    case passwordReset = "password_reset"
    case groupMembership = "group_membership"  
    case userOnboarding = "user_onboarding"
}
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE backend/Modules/M365AIAgent/M365AIAgent.psd1
  - IMPLEMENT: PowerShell module manifest with proper dependencies
  - FOLLOW pattern: CIPP module structure with Az.* and custom modules
  - NAMING: M365AIAgent module with semantic versioning
  - PLACEMENT: Module root with proper metadata and required modules list
  - CRITICAL: Must include Az.KeyVault, Az.Accounts, Microsoft.Graph dependencies

Task 2: CREATE backend/Modules/M365AIAgent/Classes/AIModels.ps1  
  - IMPLEMENT: PowerShell classes for AI request/response models
  - FOLLOW pattern: Strong typing with validation attributes
  - NAMING: PascalCase class names, camelCase properties
  - DEPENDENCIES: None (base classes)
  - PLACEMENT: Classes folder for PowerShell class definitions
  - CRITICAL: Ensure JSON serialization compatibility

Task 3: CREATE backend/Modules/M365AIAgent/Private/Invoke-AIClassification.ps1
  - IMPLEMENT: Dual-model AI classification (OpenAI + Claude) with consensus engine
  - FOLLOW pattern: CIPP error handling and logging patterns
  - NAMING: Verb-Noun PowerShell naming convention
  - DEPENDENCIES: Classes from Task 2, secure credential management
  - PLACEMENT: Private functions folder (internal use only)
  - CRITICAL: Implement circuit breaker and retry logic for AI API calls

Task 4: CREATE backend/Functions/EmailIntake/run.ps1
  - IMPLEMENT: HTTP trigger function for Exchange Online webhook processing
  - FOLLOW pattern: Azure Functions PowerShell HTTP trigger structure
  - NAMING: run.ps1 as Azure Functions entry point
  - DEPENDENCIES: M365AIAgent module from Tasks 1-3
  - PLACEMENT: Azure Functions folder with function.json configuration
  - CRITICAL: Validate webhook authenticity and queue for AI processing

Task 5: CREATE mobile/Sources/M365AgentApp/Models/ApprovalModels.swift
  - IMPLEMENT: Swift data models matching PowerShell backend classes
  - FOLLOW pattern: Skip Fuse Codable protocol implementation for cross-platform
  - NAMING: PascalCase structs, camelCase properties
  - DEPENDENCIES: Foundation, Skip framework
  - PLACEMENT: Models folder in mobile app structure
  - CRITICAL: Ensure JSON serialization matches PowerShell backend exactly

Task 6: CREATE mobile/Sources/M365AgentApp/Services/BiometricService.swift
  - IMPLEMENT: Cross-platform biometric authentication using Skip patterns
  - FOLLOW pattern: Skip Firebase authentication examples with LocalAuthentication
  - NAMING: Service suffix for business logic classes
  - DEPENDENCIES: LocalAuthentication, Skip framework
  - PLACEMENT: Services folder for business logic
  - CRITICAL: Handle both Face ID/Touch ID on iOS and fingerprint/face unlock on Android

Task 7: CREATE mobile/Sources/M365AgentApp/Views/ApprovalCardView.swift
  - IMPLEMENT: SwiftUI approval card with risk visualization and biometric confirmation
  - FOLLOW pattern: Skip UI component structure with cross-platform compatibility
  - NAMING: View suffix for SwiftUI views
  - DEPENDENCIES: SwiftUI, models from Task 5, services from Task 6
  - PLACEMENT: Views folder organized by feature
  - CRITICAL: Implement before/after state visualization and risk level indicators

Task 8: CREATE backend/Functions/ApprovalProcessor/run.ps1
  - IMPLEMENT: HTTP trigger to process mobile approval decisions
  - FOLLOW pattern: CIPP authentication and Graph API integration
  - NAMING: run.ps1 Azure Functions entry point
  - DEPENDENCIES: CIPP integration, M365AIAgent module, approval models
  - PLACEMENT: Azure Functions folder
  - CRITICAL: Validate biometric confirmation and execute approved actions

Task 9: CREATE backend/Tests/M365AIAgent.Tests.ps1
  - IMPLEMENT: Pester unit tests for all PowerShell functions
  - FOLLOW pattern: CIPP testing structure with mocks and assertions
  - NAMING: ModuleName.Tests.ps1 convention
  - COVERAGE: All public functions, error scenarios, AI classification accuracy
  - PLACEMENT: Tests folder in backend
  - CRITICAL: Mock external API calls (OpenAI, Claude, Microsoft Graph)

Task 10: CREATE mobile/Tests/ApprovalServiceTests.swift
  - IMPLEMENT: XCTest unit tests for mobile app services
  - FOLLOW pattern: Skip testing examples with cross-platform considerations  
  - NAMING: ServiceNameTests.swift convention
  - COVERAGE: Biometric service, API client, approval workflows
  - PLACEMENT: Tests folder in mobile app
  - CRITICAL: Mock biometric authentication and API responses
```

### Implementation Patterns & Key Details

```powershell
# CRITICAL: AI Classification Pattern with Dual Validation
function Invoke-AIClassification {
    param(
        [AIClassificationRequest]$Request
    )
    
    # OpenAI Primary Classification
    $OpenAIResult = Invoke-OpenAIClassification -Request $Request
    
    # Claude Secondary Validation  
    $ClaudeResult = Invoke-ClaudeValidation -Request $Request -PrimaryResult $OpenAIResult
    
    # Consensus Engine - require agreement for high-confidence actions
    if ($OpenAIResult.Confidence -gt 0.8 -and $ClaudeResult.Agreement -eq $true) {
        return [AIClassificationResult]@{
            Action = $OpenAIResult.Action
            Confidence = [Math]::Min($OpenAIResult.Confidence, $ClaudeResult.Confidence)
            RiskScore = [Math]::Max($OpenAIResult.RiskScore, $ClaudeResult.RiskScore)
            RequiresApproval = $true
        }
    }
    
    # GOTCHA: Default to human review for low confidence or disagreement
    return [AIClassificationResult]@{
        Action = "human_review"
        RequiresApproval = $true
    }
}

# CRITICAL: CIPP Integration Pattern
function Invoke-CIPPAction {
    param(
        [string]$TenantId,
        [string]$Action,
        [hashtable]$Parameters
    )
    
    # PATTERN: Use CIPP's existing Graph authentication
    $GraphRequest = @{
        Uri = "https://graph.microsoft.com/v1.0/$Action"  
        Method = 'POST'
        TenantId = $TenantId
        Body = $Parameters | ConvertTo-Json -Depth 10
    }
    
    try {
        $Result = Invoke-CippGraphRequest @GraphRequest
        Write-LogMessage -message "Successfully executed $Action" -Sev "Info" -tenant $TenantId
        return $Result
    }
    catch {
        Write-LogMessage -message "Failed to execute $Action" -LogData (Get-CippException -Exception $_) -Sev "Error"
        throw
    }
}
```

```swift
// CRITICAL: Skip Fuse Biometric Authentication Pattern
class BiometricService: ObservableObject {
    func authenticateForApproval(riskLevel: RiskLevel) async throws -> BiometricAuthResult {
        let context = LAContext()
        
        // PATTERN: Risk-based authentication policy
        let policy: LAPolicy = switch riskLevel {
        case .low: .deviceOwnerAuthenticationWithBiometrics
        case .medium, .high: .deviceOwnerAuthentication // Requires passcode fallback
        }
        
        let reason = "Approve M365 administrative action"
        
        // CRITICAL: Handle cross-platform differences through Skip
        #if os(iOS)
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: BiometricAuthResult(
                        success: true,
                        method: context.biometryType,
                        timestamp: Date()
                    ))
                } else {
                    continuation.resume(throwing: BiometricError.authenticationFailed)
                }
            }
        }
        #else
        // Skip transpiles this to Android biometric authentication
        return try await authenticateWithAndroidBiometric(policy: policy, reason: reason)
        #endif
    }
}

// CRITICAL: Risk-Based UI Pattern
struct ApprovalCardView: View {
    let request: ApprovalRequest
    
    var riskColor: Color {
        switch request.riskScore {
        case 0..<30: return .green
        case 30..<70: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Risk indicator with color coding
            HStack {
                RiskBadge(score: request.riskScore, color: riskColor)
                Spacer()
                Text(request.context.clientName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Before/After state visualization - CRITICAL for user understanding
            BeforeAfterView(
                currentState: request.context.currentState,
                proposedState: request.proposedActions.first?.proposedState
            )
            
            // PATTERN: Risk-appropriate approval buttons
            ApprovalButtonsView(
                riskLevel: RiskLevel(rawValue: request.riskScore),
                onApprove: { try await handleApproval() },
                onReject: { handleRejection() }
            )
        }
    }
}
```

### Integration Points

```yaml
AZURE_FUNCTIONS:
  - configuration: host.json with PowerShell 7.4 runtime
  - authentication: Azure AD service principal with Key Vault access
  - dependencies: requirements.psd1 with Az modules and CIPP integration

MICROSOFT_GRAPH:
  - permissions: Application permissions for user/group management
  - authentication: OAuth2 client credentials flow through CIPP
  - rate_limiting: Implement exponential backoff with 429 status handling

MOBILE_PUSH:
  - service: Azure Notification Hubs for cross-platform push
  - authentication: Device registration with biometric binding
  - payload: Rich notifications with approval context

DATABASE:
  - storage: Azure Table Storage for request/approval logging
  - schema: Partition by tenant, row by request ID for scalability
  - retention: 7-year retention for compliance audit trails

AI_SERVICES:
  - openai: GPT-4 with organization billing and usage tracking
  - claude: Anthropic API with proper headers and authentication
  - fallback: Queue for human review when both models fail/disagree
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# PowerShell Backend Validation
Push-Location backend/
Import-Module PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary
# Expected: Zero PSScriptAnalyzer warnings, proper PowerShell formatting

# Mobile App Validation  
cd mobile/
swift build --configuration debug
# Expected: Zero Swift compilation errors, proper Skip compatibility

# Module Dependency Check
Test-ModuleManifest backend/Modules/M365AIAgent/M365AIAgent.psd1
# Expected: Valid module manifest with all dependencies resolvable
```

### Level 2: Unit Tests (Component Validation)

```bash
# PowerShell Unit Tests with Pester
Push-Location backend/
Invoke-Pester -Path Tests/ -CodeCoverage -CodeCoverageThreshold 80
# Expected: >80% code coverage, all tests pass

# AI Classification Accuracy Tests
Invoke-Pester -Path Tests/AIClassification.Tests.ps1 -Tag "Integration" 
# Expected: >95% accuracy on test dataset of email/ticket samples

# Mobile App Unit Tests
cd mobile/
swift test --enable-code-coverage
# Expected: All unit tests pass, services properly mocked

# Biometric Authentication Tests
swift test --filter BiometricServiceTests
# Expected: Both iOS and Android paths tested through Skip mocking
```

### Level 3: Integration Testing (System Validation)

```bash
# Azure Functions Local Testing
func start --port 7071 --cors "*"
# Health check
curl -X GET http://localhost:7071/api/health

# Email Intake Integration Test  
curl -X POST http://localhost:7071/api/EmailIntake \
  -H "Content-Type: application/json" \
  -d '{
    "content": "John Smith forgot his password and needs it reset",
    "source": "email",
    "tenantId": "test-tenant-id"
  }'
# Expected: AI classification result with high confidence password reset

# Mobile App Integration with Backend
# Start mobile app in simulator
skip run ios -- --debug
# Test full approval workflow from notification to execution

# CIPP Integration Validation
# Connect to test CIPP instance and verify Graph API permissions
Test-CippAccess -TenantId "test-tenant" -Permissions @("User.ReadWrite.All", "Group.ReadWrite.All")
# Expected: All required permissions available

# End-to-End Workflow Test
# Email → AI Classification → Mobile Approval → CIPP Execution → Audit Log
./infrastructure/scripts/test-e2e-workflow.ps1
# Expected: Complete workflow in <2 minutes with audit trail
```

### Level 4: Creative & Domain-Specific Validation

```bash
# AI Model Performance Validation
./Tests/validate-ai-accuracy.ps1 -TestDataSet "production-samples" -MinAccuracy 95
# Expected: >95% accuracy on real-world MSP request samples

# Security Penetration Testing
# Test biometric bypass attempts
./Tests/security-validation.ps1 -TestSuite "BiometricBypass"
# Expected: No successful bypass of biometric authentication

# Load Testing with Concurrent Requests
# Simulate high-volume MSP environment
k6 run Tests/load-test.js --vus 50 --duration 5m
# Expected: <500ms p95 latency, <1% error rate

# Compliance Audit Trail Validation
./Tests/audit-compliance.ps1 -Standard "SOC2" -SampleSize 100
# Expected: Complete audit trail for 100% of administrative actions

# Mobile App Accessibility Testing
# Test with VoiceOver/TalkBack enabled
./Tests/accessibility-validation.swift
# Expected: Full functionality with screen readers, WCAG AA compliance

# Cross-Platform Mobile Testing
# Test Skip Fuse transpilation accuracy
skip test android --device emulator
skip test ios --device simulator  
# Expected: Identical functionality across iOS and Android platforms

# Production Environment Validation
# Deploy to staging environment and run full test suite
./infrastructure/scripts/deploy-staging.ps1
./Tests/staging-validation.ps1
# Expected: All tests pass in production-like environment
```

## Final Validation Checklist

### Technical Validation

- [ ] All PowerShell modules pass PSScriptAnalyzer with zero warnings
- [ ] Unit test coverage >80% for both backend and mobile app
- [ ] All AI classification tests achieve >95% accuracy on test dataset
- [ ] Mobile app builds successfully for both iOS and Android via Skip
- [ ] Azure Functions deploy and run without errors in staging environment
- [ ] CIPP integration tests pass with proper Graph API permissions
- [ ] End-to-end workflow completes in <2 minutes from email to execution

### Feature Validation

- [ ] Email intake correctly processes and classifies password reset requests
- [ ] Group membership changes trigger appropriate risk assessment and approval workflow
- [ ] Mobile app displays risk-appropriate UI with before/after visualization
- [ ] Biometric authentication works on both iOS (Face/Touch ID) and Android (fingerprint/face)
- [ ] High-risk actions trigger multi-level approval workflow correctly
- [ ] All administrative actions generate complete audit trails
- [ ] Push notifications deliver within 30 seconds of request detection

### Security Validation

- [ ] All API endpoints properly validate authentication tokens
- [ ] Biometric confirmation required for all approval actions
- [ ] No sensitive data logged in plain text
- [ ] AI API keys secured in Azure Key Vault
- [ ] Mobile app uses certificate pinning for backend communication
- [ ] Session timeouts enforce security policies
- [ ] Audit trails include biometric confirmation hashes

### Code Quality Validation

- [ ] PowerShell code follows CIPP patterns and naming conventions
- [ ] Swift code follows Skip best practices for cross-platform compatibility
- [ ] Error handling implemented at all integration points
- [ ] Logging provides sufficient detail for troubleshooting without exposing secrets
- [ ] Configuration externalized to environment variables and Key Vault
- [ ] Database schemas support multi-tenant scalability patterns

### Documentation & Deployment

- [ ] API documentation generated and accessible
- [ ] Mobile app includes proper usage descriptions for biometric permissions
- [ ] Azure Resource Manager templates deploy successfully
- [ ] Environment variables documented with example values
- [ ] Troubleshooting guides created for common failure scenarios
- [ ] Performance benchmarks documented for scaling decisions

---

## Anti-Patterns to Avoid

- ❌ Don't hardcode AI API keys - use Azure Key Vault integration
- ❌ Don't ignore AI model disagreements - always escalate to human review
- ❌ Don't skip biometric confirmation for any approval action
- ❌ Don't store approval decisions without complete audit context
- ❌ Don't implement custom Graph API authentication - use CIPP patterns
- ❌ Don't assume Skip transpilation is perfect - test both platforms
- ❌ Don't process high-risk actions without secondary approval validation
- ❌ Don't log sensitive user data or authentication tokens
- ❌ Don't implement synchronous AI API calls - use proper async patterns
- ❌ Don't deploy without comprehensive integration testing