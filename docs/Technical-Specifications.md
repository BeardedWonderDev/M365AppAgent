# M365 AI Agent - Technical Specifications
**Developer Implementation Guide**

---

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Component Specifications](#component-specifications)
3. [API Definitions](#api-definitions)
4. [Database Schema](#database-schema)
5. [Security Implementation](#security-implementation)
6. [Deployment Architecture](#deployment-architecture)
7. [Development Environment Setup](#development-environment-setup)
8. [Testing Requirements](#testing-requirements)

---

## System Architecture

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    M365 AI Agent Platform                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │   Intake    │  │ AI Detection │  │   Mobile Approval       │ │
│  │   Layer     │  │   Engine     │  │     Interface           │ │
│  └─────────────┘  └──────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │   CIPP-API  │  │   Execution  │  │    Audit & Logging      │ │
│  │ Integration │  │    Engine    │  │       System            │ │
│  └─────────────┘  └──────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

#### Backend Services
- **Platform**: Azure Functions (PowerShell Core 7.x)
- **Language**: PowerShell 7.4+
- **Framework**: CIPP-API extension architecture
- **Authentication**: Azure AD/Entra ID with MSAL
- **Storage**: Azure Table Storage + Cosmos DB
- **Messaging**: Azure Service Bus
- **Monitoring**: Application Insights

#### AI Processing Layer
- **Primary NLP**: OpenAI GPT-4 API (latest model)
- **Secondary Validation**: Claude 3.5 Sonnet API
- **Processing**: Azure Cognitive Services (supplementary)
- **Model Management**: Azure ML (for fine-tuning)

#### Mobile Application
- **Framework**: Skip Fuse 1.5+
- **iOS**: SwiftUI 5.0+, iOS 16+
- **Android**: Jetpack Compose (transpiled)
- **Authentication**: Platform biometrics + OAuth2
- **Push Notifications**: APNs/FCM via Azure Notification Hubs

#### Integration Layer
- **Microsoft Graph**: v1.0 API
- **Email**: Exchange Online webhooks
- **Ticketing**: NinjaRMM REST API v3.0
- **CIPP**: Internal API extension

---

## Component Specifications

### 1. Intake Layer

#### Email Monitoring Service
**Function**: `EmailIntakeFunction`
**Trigger**: HTTP webhook from Exchange Online
**Runtime**: PowerShell 7.4

```powershell
# Function signature
function Start-EmailIntake {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$EmailData,
        
        [Parameter()]
        [hashtable]$Context
    )
}
```

**Input Schema**:
```json
{
    "notificationUrl": "string",
    "clientState": "string", 
    "expirationDateTime": "datetime",
    "resource": "string",
    "tenantId": "string",
    "siteUrl": "string",
    "webId": "string"
}
```

**Processing Logic**:
1. Validate webhook authenticity
2. Extract email metadata and content
3. Identify tenant and sender context
4. Queue for AI processing
5. Return acknowledgment

#### Ticketing System Monitor
**Function**: `TicketIntakeFunction`
**Trigger**: HTTP webhook from NinjaRMM
**Runtime**: PowerShell 7.4

```powershell
function Start-TicketIntake {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationId,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$TicketData,
        
        [Parameter()]
        [string]$EventType
    )
}
```

### 2. AI Detection Engine

#### Request Classification Service
**Function**: `AIClassificationFunction`
**Trigger**: Service Bus queue message
**Runtime**: PowerShell 7.4 + REST API calls

```powershell
function Invoke-RequestClassification {
    param(
        [Parameter(Mandatory)]
        [string]$Content,
        
        [Parameter(Mandatory)]
        [string]$Source,
        
        [Parameter()]
        [hashtable]$Context
    )
    
    # Returns classification result
    return @{
        Action = "string"
        Confidence = "float"
        RiskScore = "int"
        Parameters = @{}
        RequiresApproval = "boolean"
    }
}
```

#### AI Model Integration

**OpenAI Integration**:
```powershell
$OpenAIConfig = @{
    Endpoint = "https://api.openai.com/v1/chat/completions"
    Model = "gpt-4-0125-preview"
    MaxTokens = 1000
    Temperature = 0.1
    SystemPrompt = $ClassificationPrompt
}
```

**Claude Integration**:
```powershell
$ClaudeConfig = @{
    Endpoint = "https://api.anthropic.com/v1/messages"
    Model = "claude-3-5-sonnet-20241022"
    MaxTokens = 1000
    SystemPrompt = $ValidationPrompt
}
```

#### Risk Assessment Engine
**Function**: `RiskAssessmentFunction`

```powershell
function Get-ActionRiskScore {
    param(
        [Parameter(Mandatory)]
        [string]$ActionType,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$TargetObject,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$TenantContext
    )
    
    # Risk scoring logic
    $BaseRisk = Get-BaseRiskScore -Action $ActionType
    $ContextRisk = Get-ContextualRisk -Object $TargetObject -Tenant $TenantContext
    $UserRisk = Get-UserRiskScore -User $TargetObject.User
    
    return [Math]::Min(100, $BaseRisk + $ContextRisk + $UserRisk)
}
```

### 3. Mobile Approval Interface

#### Skip Fuse Application Structure

**Project Structure**:
```
M365AgentApp/
├── Sources/
│   ├── M365AgentApp/
│   │   ├── App.swift
│   │   ├── Models/
│   │   │   ├── ApprovalRequest.swift
│   │   │   ├── ActionCard.swift
│   │   │   └── RiskAssessment.swift
│   │   ├── Views/
│   │   │   ├── ApprovalCardView.swift
│   │   │   ├── BiometricConfirmationView.swift
│   │   │   └── BatchApprovalView.swift
│   │   ├── Services/
│   │   │   ├── ApprovalService.swift
│   │   │   ├── NotificationService.swift
│   │   │   └── BiometricService.swift
│   │   └── Skip/
│   │       └── skip.yml
├── Tests/
└── Package.swift
```

**Core Models**:
```swift
// ApprovalRequest.swift
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
    case userOffboarding = "user_offboarding"
}

struct ProposedAction: Codable, Identifiable {
    let id: UUID
    let actionType: String
    let target: String
    let currentState: ActionState?
    let proposedState: ActionState
    let businessImpact: String?
    let securityImpact: String?
}
```

**Approval Service**:
```swift
// ApprovalService.swift
@Observable
class ApprovalService {
    private let apiClient: APIClient
    private let biometricService: BiometricService
    
    func approveRequest(
        _ request: ApprovalRequest,
        biometricResult: BiometricAuthResult
    ) async throws -> ApprovalResult {
        // Validate biometric authentication
        try await biometricService.validateAuthentication(biometricResult)
        
        // Submit approval to backend
        let response = try await apiClient.submitApproval(
            requestId: request.id,
            approved: true,
            biometricHash: biometricResult.hash,
            timestamp: Date()
        )
        
        return response
    }
}
```

#### Biometric Integration
```swift
// BiometricService.swift
class BiometricService {
    private let context = LAContext()
    
    func authenticateForApproval(
        riskLevel: RiskLevel
    ) async throws -> BiometricAuthResult {
        let policy: LAPolicy = switch riskLevel {
        case .low: .deviceOwnerAuthenticationWithBiometrics
        case .medium: .deviceOwnerAuthentication
        case .high: .deviceOwnerAuthentication
        }
        
        let reason = "Approve M365 administrative action"
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: BiometricAuthResult(
                        success: true,
                        timestamp: Date(),
                        method: self.context.biometryType
                    ))
                } else {
                    continuation.resume(throwing: BiometricError.authenticationFailed)
                }
            }
        }
    }
}
```

### 4. CIPP Integration Layer

#### Extension Architecture
**Function**: `CIPPExtensionHandler`
**Integration Pattern**: PowerShell module extension

```powershell
# CIPP extension entry point
function Invoke-M365AIAgent {
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [hashtable]$Parameters,
        
        [Parameter()]
        [string]$TenantId,
        
        [Parameter()]
        [PSCredential]$Credential
    )
    
    switch ($Action) {
        "ProcessApproval" { 
            return Invoke-ApprovalProcessor @Parameters 
        }
        "ExecuteAction" { 
            return Invoke-ActionExecutor @Parameters 
        }
        "GetAuditLog" { 
            return Get-AIAgentAuditLog @Parameters 
        }
    }
}
```

#### Graph API Integration
```powershell
# Reuse CIPP's Graph API connection
function Invoke-GraphRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        
        [Parameter()]
        [string]$Method = "GET",
        
        [Parameter()]
        [hashtable]$Body,
        
        [Parameter(Mandatory)]
        [string]$TenantId
    )
    
    # Leverage CIPP's existing Graph authentication
    $GraphRequest = @{
        Uri = $Uri
        Method = $Method
        TenantId = $TenantId
        Body = $Body | ConvertTo-Json -Depth 10
    }
    
    return Invoke-CippGraphRequest @GraphRequest
}
```

---

## API Definitions

### RESTful API Endpoints

#### Authentication
```
POST /api/auth/mobile
Content-Type: application/json

{
    "deviceId": "string",
    "biometricHash": "string",
    "mspTenantId": "string"
}

Response:
{
    "accessToken": "string",
    "refreshToken": "string",
    "expiresIn": 3600,
    "tokenType": "Bearer"
}
```

#### Approval Requests
```
GET /api/approvals/pending
Authorization: Bearer {token}
X-MSP-Tenant-ID: {tenantId}

Response:
{
    "requests": [
        {
            "id": "uuid",
            "type": "password_reset",
            "description": "Reset password for john.doe@contoso.com",
            "riskScore": 25,
            "proposedActions": [...],
            "expiresAt": "2024-01-15T10:30:00Z",
            "createdAt": "2024-01-15T10:00:00Z"
        }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20
}
```

```
POST /api/approvals/{requestId}/approve
Authorization: Bearer {token}
Content-Type: application/json

{
    "approved": true,
    "biometricConfirmation": {
        "type": "faceId",
        "hash": "string",
        "timestamp": "2024-01-15T10:35:00Z"
    },
    "comments": "string"
}

Response:
{
    "success": true,
    "executionId": "uuid",
    "estimatedCompletion": "2024-01-15T10:37:00Z"
}
```

#### Execution Status
```
GET /api/executions/{executionId}/status
Authorization: Bearer {token}

Response:
{
    "id": "uuid",
    "status": "completed|running|failed",
    "progress": 100,
    "results": [...],
    "completedAt": "2024-01-15T10:37:15Z",
    "auditLogId": "uuid"
}
```

### WebHook Endpoints

#### Email Notifications
```
POST /api/webhooks/exchange
Content-Type: application/json
X-Webhook-Signature: {signature}

{
    "subscriptionId": "string",
    "clientState": "string",
    "expirationDateTime": "2024-01-15T11:00:00Z",
    "resource": "users/{userId}/messages/{messageId}",
    "resourceData": {
        "id": "string",
        "subject": "Password reset request for John Doe"
    }
}
```

#### Ticketing System
```
POST /api/webhooks/ninja
Content-Type: application/json
X-API-Key: {apiKey}

{
    "event": "ticket.created",
    "organizationId": "string",
    "ticket": {
        "id": "string",
        "subject": "User access issue",
        "description": "John Doe can't access his email",
        "priority": "medium",
        "requester": {
            "email": "helpdesk@msp.com"
        }
    }
}
```

---

## Database Schema

### Azure Table Storage Schema

#### ApprovalRequests Table
```
PartitionKey: {MSPTenantId}
RowKey: {RequestId}

Properties:
- RequestType: string
- SourceSystem: string (email|ticket)
- SourceId: string
- Content: string (original request)
- Classification: JSON
- RiskScore: int32
- Status: string (pending|approved|rejected|expired)
- CreatedAt: DateTime
- ExpiresAt: DateTime
- ApprovedAt: DateTime?
- ApprovedBy: string?
- BiometricHash: string?
```

#### ExecutionLog Table
```
PartitionKey: {MSPTenantId}
RowKey: {ExecutionId}

Properties:
- RequestId: string
- ActionType: string
- TargetTenant: string
- Parameters: JSON
- Status: string (queued|running|completed|failed)
- StartedAt: DateTime
- CompletedAt: DateTime?
- Results: JSON
- ErrorMessage: string?
```

#### AuditTrail Table
```
PartitionKey: {MSPTenantId}-{Date}
RowKey: {Timestamp}-{AuditId}

Properties:
- EventType: string
- UserId: string
- DeviceId: string
- Action: string
- TargetObject: string
- TargetTenant: string
- Success: boolean
- IPAddress: string
- UserAgent: string
- BiometricMethod: string?
```

### Cosmos DB Collections

#### AIModelPerformance
```json
{
    "id": "uuid",
    "partitionKey": "performance-metrics",
    "modelName": "gpt-4",
    "date": "2024-01-15",
    "accuracy": 0.95,
    "confidence": 0.88,
    "falsePositives": 2,
    "falseNegatives": 1,
    "totalProcessed": 150,
    "averageResponseTime": 850
}
```

---

## Security Implementation

### Authentication & Authorization

#### Mobile App Security
```swift
// Secure token storage
class SecureTokenStorage {
    private let keychain = Keychain(service: "com.m365agent.tokens")
    
    func store(token: String, for key: String) throws {
        try keychain
            .accessibility(.whenUnlockedThisDeviceOnly)
            .set(token, key: key)
    }
    
    func retrieve(for key: String) throws -> String? {
        return try keychain.get(key)
    }
}

// Certificate pinning
class APIClient {
    private lazy var session: URLSession = {
        let delegate = PinnedCertificateDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
}

class PinnedCertificateDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Certificate pinning implementation
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate against pinned certificates
        let isValid = validateServerTrust(serverTrust)
        
        if isValid {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

#### Backend Security
```powershell
# JWT validation
function Test-JWTToken {
    param(
        [Parameter(Mandatory)]
        [string]$Token,
        
        [Parameter(Mandatory)]
        [string]$Issuer,
        
        [Parameter(Mandatory)]
        [string]$Audience
    )
    
    try {
        $DecodedToken = [System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler]::new().ReadJwtToken($Token)
        
        # Validate issuer, audience, expiration
        if ($DecodedToken.Issuer -ne $Issuer) {
            throw "Invalid issuer"
        }
        
        if ($DecodedToken.Audiences -notcontains $Audience) {
            throw "Invalid audience"
        }
        
        if ($DecodedToken.ValidTo -lt (Get-Date)) {
            throw "Token expired"
        }
        
        return $DecodedToken
    }
    catch {
        Write-Error "JWT validation failed: $_"
        return $null
    }
}

# Input sanitization
function Get-SanitizedInput {
    param(
        [Parameter(Mandatory)]
        [string]$Input,
        
        [Parameter()]
        [string]$Type = "General"
    )
    
    switch ($Type) {
        "Email" {
            if ($Input -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                return $Input
            }
        }
        "UPN" {
            if ($Input -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                return $Input
            }
        }
        "ObjectId" {
            if ($Input -match '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$') {
                return $Input
            }
        }
        default {
            # General sanitization
            return [System.Web.HttpUtility]::HtmlEncode($Input)
        }
    }
    
    throw "Invalid input format for type: $Type"
}
```

### Encryption

#### Data at Rest
```powershell
# Azure Key Vault integration
function Get-EncryptionKey {
    param(
        [Parameter(Mandatory)]
        [string]$KeyName
    )
    
    $VaultUri = $env:AZURE_KEY_VAULT_URI
    $Key = Get-AzKeyVaultKey -VaultName $VaultUri -Name $KeyName
    
    return $Key
}

function Protect-SensitiveData {
    param(
        [Parameter(Mandatory)]
        [string]$PlainText,
        
        [Parameter(Mandatory)]
        [string]$KeyName
    )
    
    $Key = Get-EncryptionKey -KeyName $KeyName
    $EncryptedData = [System.Text.Encoding]::UTF8.GetBytes($PlainText) | 
                    Protect-Data -Key $Key.Key
    
    return [Convert]::ToBase64String($EncryptedData)
}
```

#### Data in Transit
```powershell
# TLS 1.3 enforcement
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13

# HTTPS client configuration
$HttpClient = [System.Net.Http.HttpClient]::new()
$HttpClient.DefaultRequestHeaders.Add("User-Agent", "M365AIAgent/1.0")
$HttpClient.Timeout = [TimeSpan]::FromSeconds(30)
```

---

## Deployment Architecture

### Azure Functions Deployment

#### Function App Configuration
```json
{
    "version": "2.0",
    "extensionBundle": {
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[3.*, 4.0.0)"
    },
    "functionTimeout": "00:05:00",
    "logging": {
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": true
            }
        }
    },
    "managedDependency": {
        "enabled": true
    }
}
```

#### PowerShell Dependencies
```powershell
# requirements.psd1
@{
    'Az' = '9.*'
    'Microsoft.Graph' = '1.28.*'
    'PSFramework' = '1.*'
    'ImportExcel' = '7.*'
}
```

#### ARM Template (Function App)
```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "functionAppName": {
            "type": "string",
            "metadata": {
                "description": "Name of the function app"
            }
        }
    },
    "resources": [
        {
            "type": "Microsoft.Web/sites",
            "apiVersion": "2021-02-01",
            "name": "[parameters('functionAppName')]",
            "location": "[resourceGroup().location]",
            "kind": "functionapp",
            "properties": {
                "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', variables('hostingPlanName'))]",
                "siteConfig": {
                    "powerShellVersion": "7.2",
                    "functionAppScaleLimit": 200,
                    "minimumElasticInstanceCount": 1
                }
            }
        }
    ]
}
```

### Container Orchestration (Alternative)

#### Dockerfile
```dockerfile
FROM mcr.microsoft.com/azure-functions/powershell:4-powershell7.2-core-tools

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

COPY . /home/site/wwwroot

RUN cd /home/site/wwwroot && \
    func extensions install
```

#### Docker Compose (Development)
```yaml
version: '3.8'
services:
  m365-ai-agent:
    build: .
    ports:
      - "7071:80"
    environment:
      - AzureWebJobsStorage=${AZURE_STORAGE_CONNECTION_STRING}
      - FUNCTIONS_WORKER_RUNTIME=powershell
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
    depends_on:
      - azurite

  azurite:
    image: mcr.microsoft.com/azure-storage/azurite
    ports:
      - "10000:10000"
      - "10001:10001"
      - "10002:10002"
```

---

## Development Environment Setup

### Prerequisites

#### Required Software
- **PowerShell 7.4+**
- **Azure Functions Core Tools v4**
- **Xcode 15+ (for iOS development)**
- **Visual Studio Code** with extensions:
  - Azure Functions
  - PowerShell
  - Skip for VS Code (when available)
- **Git 2.40+**
- **Node.js 18+ (for tooling)**

#### Azure Services Setup
```powershell
# Azure CLI setup script
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create --name "rg-m365-ai-agent-dev" --location "East US 2"

# Create storage account
az storage account create \
    --name "stm365aiagentdev" \
    --resource-group "rg-m365-ai-agent-dev" \
    --location "East US 2" \
    --sku "Standard_LRS"

# Create function app
az functionapp create \
    --name "func-m365-ai-agent-dev" \
    --resource-group "rg-m365-ai-agent-dev" \
    --storage-account "stm365aiagentdev" \
    --runtime "powershell" \
    --runtime-version "7.2" \
    --functions-version "4"
```

### Local Development Setup

#### PowerShell Profile Configuration
```powershell
# Microsoft.PowerShell_profile.ps1
Import-Module Az
Import-Module Microsoft.Graph.Authentication

# AI Agent development functions
function Start-LocalFunction {
    param([string]$FunctionName)
    
    Push-Location "src/functions/$FunctionName"
    func start --verbose
    Pop-Location
}

function Test-AIClassification {
    param([string]$TestContent)
    
    $Result = Invoke-RestMethod -Uri "http://localhost:7071/api/classify" -Method POST -Body @{
        content = $TestContent
        source = "email"
    } -ContentType "application/json"
    
    return $Result
}
```

#### Skip Fuse Project Setup
```bash
# Install Skip
curl -L https://skip.tools/install | bash

# Create new Skip Fuse project
skip init M365AgentApp --fuse

# Add to Package.swift
dependencies: [
    .package(url: "https://source.skip.tools/skip-fuse.git", from: "0.0.0")
]
```

#### Environment Variables Template
```powershell
# .env.development
$env:AZURE_STORAGE_CONNECTION_STRING = "UseDevelopmentStorage=true"
$env:OPENAI_API_KEY = "sk-..."
$env:CLAUDE_API_KEY = "..."
$env:AZURE_CLIENT_ID = "..."
$env:AZURE_CLIENT_SECRET = "..."
$env:AZURE_TENANT_ID = "..."
$env:GRAPH_SCOPES = "https://graph.microsoft.com/.default"
$env:LOG_LEVEL = "Debug"
$env:ENVIRONMENT = "Development"
```

---

## Testing Requirements

### Unit Testing Framework

#### PowerShell Unit Tests (Pester)
```powershell
# Tests/AIClassification.Tests.ps1
Describe "AI Classification Tests" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../src/modules/AIClassification.psm1" -Force
    }
    
    Context "Password Reset Classification" {
        It "Should correctly identify password reset request" {
            $TestContent = "Hi, John Doe forgot his password and can't log in. Please reset it."
            
            $Result = Invoke-RequestClassification -Content $TestContent -Source "email"
            
            $Result.Action | Should -Be "password_reset"
            $Result.Confidence | Should -BeGreaterThan 0.8
            $Result.RiskScore | Should -BeLessThan 50
        }
        
        It "Should handle ambiguous requests" {
            $TestContent = "User having trouble with computer"
            
            $Result = Invoke-RequestClassification -Content $TestContent -Source "email"
            
            $Result.Action | Should -Be "unknown"
            $Result.Confidence | Should -BeLessThan 0.7
        }
    }
    
    Context "Risk Assessment" {
        It "Should assign high risk to admin group changes" {
            $TestContent = "Add John to Domain Admins group"
            
            $Result = Invoke-RequestClassification -Content $TestContent -Source "email"
            
            $Result.RiskScore | Should -BeGreaterThan 80
            $Result.RequiresApproval | Should -Be $true
        }
    }
}
```

#### Swift Unit Tests (XCTest + Skip)
```swift
// Tests/ApprovalServiceTests.swift
import XCTest
@testable import M365AgentApp

final class ApprovalServiceTests: XCTestCase {
    var approvalService: ApprovalService!
    var mockAPIClient: MockAPIClient!
    var mockBiometricService: MockBiometricService!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        mockBiometricService = MockBiometricService()
        approvalService = ApprovalService(
            apiClient: mockAPIClient,
            biometricService: mockBiometricService
        )
    }
    
    func testApprovalRequestSuccess() async throws {
        // Given
        let request = ApprovalRequest.mockPasswordReset()
        mockBiometricService.authResult = .success(method: .faceID)
        mockAPIClient.approvalResult = .success
        
        // When
        let result = try await approvalService.approveRequest(
            request,
            biometricResult: mockBiometricService.authResult.get()
        )
        
        // Then
        XCTAssertEqual(result.status, .approved)
        XCTAssertTrue(mockAPIClient.submitApprovalCalled)
    }
    
    func testBiometricFailure() async {
        // Given
        let request = ApprovalRequest.mockPasswordReset()
        mockBiometricService.authResult = .failure(.authenticationFailed)
        
        // When/Then
        do {
            _ = try await approvalService.approveRequest(
                request,
                biometricResult: try mockBiometricService.authResult.get()
            )
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is BiometricError)
        }
    }
}
```

### Integration Testing

#### API Integration Tests
```powershell
# Tests/Integration/APIIntegration.Tests.ps1
Describe "API Integration Tests" -Tag "Integration" {
    BeforeAll {
        # Setup test environment
        $TestTenantId = $env:TEST_TENANT_ID
        $TestSubscription = $env:TEST_SUBSCRIPTION_ID
        
        if (-not $TestTenantId -or -not $TestSubscription) {
            throw "Test environment variables not set"
        }
    }
    
    Context "Graph API Integration" {
        It "Should successfully authenticate with Graph API" {
            $GraphToken = Get-GraphAccessToken -TenantId $TestTenantId
            
            $GraphToken | Should -Not -BeNullOrEmpty
            $GraphToken.access_token | Should -Not -BeNullOrEmpty
        }
        
        It "Should retrieve user information" {
            $TestUser = "test@$TestTenantId"
            
            $UserInfo = Get-GraphUser -UserPrincipalName $TestUser
            
            $UserInfo.userPrincipalName | Should -Be $TestUser
            $UserInfo.id | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "CIPP API Integration" {
        It "Should extend CIPP functionality" {
            $Result = Invoke-CIPPExtension -Action "ProcessApproval" -Parameters @{
                RequestId = "test-123"
                Approved = $true
            }
            
            $Result.Success | Should -Be $true
        }
    }
}
```

### Performance Testing

#### Load Testing Configuration
```powershell
# Tests/Performance/LoadTest.ps1
param(
    [int]$ConcurrentUsers = 50,
    [int]$DurationMinutes = 10,
    [string]$TargetEndpoint = "https://func-m365-ai-agent-dev.azurewebsites.net"
)

Describe "Performance Load Tests" -Tag "Performance" {
    It "Should handle concurrent classification requests" {
        $Jobs = @()
        
        1..$ConcurrentUsers | ForEach-Object {
            $Jobs += Start-Job -ScriptBlock {
                param($Endpoint, $Duration)
                
                $StartTime = Get-Date
                $RequestCount = 0
                $Errors = 0
                
                while ((Get-Date) -lt $StartTime.AddMinutes($Duration)) {
                    try {
                        $Response = Invoke-RestMethod -Uri "$Endpoint/api/classify" -Method POST -Body @{
                            content = "Test user needs password reset"
                            source = "email"
                        } -ContentType "application/json" -TimeoutSec 30
                        
                        $RequestCount++
                    }
                    catch {
                        $Errors++
                    }
                    
                    Start-Sleep -Milliseconds 100
                }
                
                return @{
                    RequestCount = $RequestCount
                    Errors = $Errors
                    Duration = $Duration
                }
            } -ArgumentList $TargetEndpoint, $DurationMinutes
        }
        
        $Results = $Jobs | Wait-Job | Receive-Job
        $Jobs | Remove-Job
        
        $TotalRequests = ($Results | Measure-Object -Property RequestCount -Sum).Sum
        $TotalErrors = ($Results | Measure-Object -Property Errors -Sum).Sum
        $ErrorRate = $TotalErrors / $TotalRequests * 100
        
        Write-Host "Total Requests: $TotalRequests"
        Write-Host "Total Errors: $TotalErrors"
        Write-Host "Error Rate: $ErrorRate%"
        Write-Host "Requests per Second: $($TotalRequests / ($DurationMinutes * 60))"
        
        $ErrorRate | Should -BeLessThan 5
        $TotalRequests | Should -BeGreaterThan ($ConcurrentUsers * $DurationMinutes * 2)
    }
}
```

### Security Testing

#### Security Validation Tests
```powershell
# Tests/Security/SecurityValidation.Tests.ps1
Describe "Security Validation Tests" -Tag "Security" {
    Context "Input Sanitization" {
        It "Should reject malicious email content" {
            $MaliciousContent = "<script>alert('xss')</script>Password reset needed"
            
            { Invoke-RequestClassification -Content $MaliciousContent -Source "email" } | 
                Should -Throw "*Invalid input*"
        }
        
        It "Should validate email addresses properly" {
            $InvalidEmails = @(
                "notanemail",
                "test@",
                "@domain.com",
                "test..test@domain.com"
            )
            
            foreach ($Email in $InvalidEmails) {
                { Get-SanitizedInput -Input $Email -Type "Email" } | 
                    Should -Throw "*Invalid input format*"
            }
        }
    }
    
    Context "Authentication" {
        It "Should reject expired JWT tokens" {
            $ExpiredToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..." # Expired token
            
            $Result = Test-JWTToken -Token $ExpiredToken -Issuer "test" -Audience "test"
            
            $Result | Should -BeNullOrEmpty
        }
        
        It "Should reject tokens with invalid signatures" {
            $InvalidToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.invalid.signature"
            
            $Result = Test-JWTToken -Token $InvalidToken -Issuer "test" -Audience "test"
            
            $Result | Should -BeNullOrEmpty
        }
    }
}
```

---

## Monitoring & Observability

### Application Insights Configuration
```powershell
# Telemetry tracking
function Write-AIAgentTelemetry {
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter()]
        [hashtable]$Properties = @{},
        
        [Parameter()]
        [hashtable]$Metrics = @{}
    )
    
    $TelemetryProperties = $Properties + @{
        'Environment' = $env:ENVIRONMENT
        'Version' = $env:APP_VERSION
        'Timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }
    
    # Send to Application Insights
    $Body = @{
        name = "Microsoft.ApplicationInsights.Event"
        time = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        data = @{
            baseType = "EventData"
            baseData = @{
                name = $EventName
                properties = $TelemetryProperties
                measurements = $Metrics
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri $env:APPINSIGHTS_ENDPOINT -Method POST -Body $Body -ContentType "application/json"
    }
    catch {
        Write-Warning "Failed to send telemetry: $_"
    }
}

# Usage examples
Write-AIAgentTelemetry -EventName "RequestClassified" -Properties @{
    'RequestType' = 'password_reset'
    'Confidence' = '0.95'
    'RiskScore' = '25'
} -Metrics @{
    'ProcessingTimeMs' = 850
}
```

### Health Check Endpoints
```powershell
# HealthCheck function
function Get-SystemHealth {
    $Health = @{
        Status = "Healthy"
        Timestamp = (Get-Date).ToString('o')
        Components = @{}
    }
    
    # Check OpenAI API
    try {
        $OpenAIResponse = Invoke-RestMethod -Uri "https://api.openai.com/v1/models" -Headers @{
            'Authorization' = "Bearer $env:OPENAI_API_KEY"
        } -TimeoutSec 10
        $Health.Components.OpenAI = "Healthy"
    }
    catch {
        $Health.Components.OpenAI = "Unhealthy: $($_.Exception.Message)"
        $Health.Status = "Degraded"
    }
    
    # Check Claude API
    try {
        $ClaudeResponse = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" -Method POST -Headers @{
            'x-api-key' = $env:CLAUDE_API_KEY
            'anthropic-version' = '2023-06-01'
            'content-type' = 'application/json'
        } -Body '{"messages":[{"role":"user","content":"test"}],"model":"claude-3-sonnet-20240229","max_tokens":1}' -TimeoutSec 10
        $Health.Components.Claude = "Healthy"
    }
    catch {
        $Health.Components.Claude = "Unhealthy: $($_.Exception.Message)"
        $Health.Status = "Degraded"
    }
    
    # Check Graph API
    try {
        $GraphToken = Get-GraphAccessToken
        $Health.Components.GraphAPI = "Healthy"
    }
    catch {
        $Health.Components.GraphAPI = "Unhealthy: $($_.Exception.Message)"
        $Health.Status = "Degraded"
    }
    
    return $Health
}
```

---

*Document Version*: 1.0  
*Date*: September 3, 2025  
*Author*: Development Team & Technical Architecture  
*Status*: Ready for Implementation