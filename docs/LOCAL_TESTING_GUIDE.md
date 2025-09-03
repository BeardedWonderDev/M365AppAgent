# 🧪 AI TenantShield - Local Testing Guide

This guide provides step-by-step instructions for testing the AI TenantShield implementation locally without requiring full Azure deployment.

## 📋 Prerequisites

### Required Tools
- **PowerShell 7.4+**: `brew install powershell`
- **Azure Functions Core Tools v4**: `brew install azure-functions-core-tools@4`
- **Skip Framework** (for mobile): `brew install skiptools/skip/skip`
- **Docker** (optional): For isolated testing
- **Xcode** (for iOS testing): From Mac App Store
- **Node.js 18+**: `brew install node` (for Azure Functions)

### Optional Tools
- **Pester 5.0+**: PowerShell testing framework
- **PSScriptAnalyzer**: PowerShell linting tool
- **Android Studio**: For Android testing

## 1️⃣ Backend Testing (PowerShell/Azure Functions)

### Quick Validation Test
```bash
# Navigate to project root
cd /Users/brianpistone/Development/CoManaged/M365AppAgent

# Run quick validation
pwsh -Command "& {
    Write-Host 'Testing AI TenantShield Backend...' -ForegroundColor Cyan
    
    # Test module manifest
    Test-ModuleManifest ./backend/Modules/M365AIAgent/M365AIAgent.psd1
    
    # Import and verify module
    Import-Module ./backend/Modules/M365AIAgent/M365AIAgent.psd1 -Force
    Get-Command -Module M365AIAgent | Format-Table Name, CommandType
    
    Write-Host '✅ Backend validation successful' -ForegroundColor Green
}"
```

### Test PowerShell Module Directly

#### Step 1: Set Up Test Environment
```powershell
cd backend
pwsh

# Set test environment variables
$env:AZURE_FUNCTIONS_ENVIRONMENT = "Development"
$env:OPENAI_API_KEY = "sk-test-key"  # Replace with real key for actual testing
$env:KEY_VAULT_NAME = ""  # Empty for local testing
```

#### Step 2: Import and Test Module
```powershell
# Import the module
Import-Module ./Modules/M365AIAgent/M365AIAgent.psd1 -Force -Verbose

# Verify module loaded
Get-Module M365AIAgent

# List available functions
Get-Command -Module M365AIAgent | Format-Table Name, CommandType

# Test class creation
$testRequest = [AIClassificationRequest]::new()
$testRequest.Content = "Please reset password for john.smith@company.com"
$testRequest.Source = "email"
$testRequest.TenantId = "test-tenant-123"
$testRequest.ClientName = "Contoso Corp"
$testRequest

# Test with mock result (no API call)
$mockResult = [AIClassificationResult]::new()
$mockResult.Action = "password_reset"
$mockResult.Confidence = 0.95
$mockResult.RiskScore = 30
$mockResult.RequestType = "password_reset"
$mockResult.RequiresApproval = $true
$mockResult | Format-List
```

#### Step 3: Test AI Classification (Requires OpenAI API Key)
```powershell
# Only run with valid OpenAI API key
$env:OPENAI_API_KEY = "your-actual-openai-key-here"

# Test classification
$request = [AIClassificationRequest]::new(
    "John Smith forgot his password and needs it reset urgently",
    "email",
    "tenant-456"
)

# This will make an actual API call
$result = Invoke-AIClassification -Request $request -EnableDualValidation $false
$result | Format-List
```

### Run Unit Tests

#### Install Pester and Run Tests
```powershell
cd backend/Tests

# Install Pester if not installed
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module -Name Pester -Force -Scope CurrentUser
}

# Run all tests
./Run-Tests.ps1 -TestType All -Verbose

# Run specific test categories
./Run-Tests.ps1 -TestType Unit      # Unit tests only
./Run-Tests.ps1 -TestType Integration # Integration tests
./Run-Tests.ps1 -TestType Performance # Performance tests

# Run with coverage report
./Run-Tests.ps1 -TestType All -GenerateCoverage

# Direct Pester execution
Invoke-Pester -Path ./M365AIAgent.Tests.ps1 -Output Detailed
```

### Test Azure Functions Locally

#### Step 1: Install Dependencies
```bash
cd backend

# Install Azure Functions Core Tools if not installed
brew tap azure/functions
brew install azure-functions-core-tools@4

# Verify installation
func --version
```

#### Step 2: Start Function App
```bash
# Start the local Azure Functions host
func start --port 7071

# You should see output like:
# Functions:
#   EmailIntake: [POST] http://localhost:7071/api/email/intake
#   ApprovalProcessor: [POST] http://localhost:7071/api/approval/process
```

#### Step 3: Test Endpoints
```bash
# Test EmailIntake endpoint
curl -X POST http://localhost:7071/api/email/intake \
  -H "Content-Type: application/json" \
  -H "x-api-key: test-key" \
  -d '{
    "subject": "Password Reset Request",
    "body": "Please reset password for john.smith@company.com",
    "from": "helpdesk@example.com",
    "to": "support@company.com",
    "tenant": "test-tenant",
    "clientName": "Contoso Corp"
  }'

# Test ApprovalProcessor endpoint
curl -X POST http://localhost:7071/api/approval/process \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "requestId": "550e8400-e29b-41d4-a716-446655440000",
    "approved": true,
    "biometricConfirmation": {
      "success": true,
      "method": "FaceID",
      "timestamp": "2025-01-03T10:00:00Z",
      "hash": "test-hash-12345"
    }
  }'
```

## 2️⃣ Mobile App Testing (Swift/Skip Fuse)

### Prerequisites Setup
```bash
# Install Skip framework
brew install skiptools/skip/skip

# Verify Skip installation
skip checkup

# You should see:
# ✓ Skip 1.0.0
# ✓ Swift 5.9+
# ✓ Xcode 15+
# ✓ Android setup (if configured)
```

### Run Swift Tests
```bash
cd mobile

# Build the package
swift build

# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter ApprovalServiceTests
swift test --filter BiometricServiceTests

# Verbose output
swift test --verbose
```

### Build and Run Mobile App

#### iOS Simulator (Requires Xcode)
```bash
cd mobile

# Build for iOS
skip build ios

# Run in iOS simulator
skip run ios

# Run on specific simulator
skip run ios --device "iPhone 15 Pro"
```

#### Android Emulator (Requires Android Studio)
```bash
cd mobile

# Build for Android
skip build android

# Run in Android emulator
skip run android

# Run on specific emulator
skip run android --device "Pixel_7_API_33"
```

## 3️⃣ Docker-Based Testing (Isolated Environment)

### Create Docker Environment
```bash
# Create docker-compose.yml in project root
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Azure Storage Emulator
  azurite:
    image: mcr.microsoft.com/azure-storage/azurite:latest
    container_name: ai-tenantshield-storage
    ports:
      - "10000:10000"  # Blob
      - "10001:10001"  # Queue
      - "10002:10002"  # Table
    volumes:
      - azurite-data:/data

  # Azure Functions Runtime
  functions:
    image: mcr.microsoft.com/azure-functions/powershell:4-powershell7.4
    container_name: ai-tenantshield-functions
    ports:
      - "7071:80"
    environment:
      - AzureWebJobsStorage=DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite:10000/devstoreaccount1;QueueEndpoint=http://azurite:10001/devstoreaccount1;TableEndpoint=http://azurite:10002/devstoreaccount1;
      - FUNCTIONS_WORKER_RUNTIME=powershell
      - FUNCTIONS_WORKER_RUNTIME_VERSION=7.4
      - AZURE_FUNCTIONS_ENVIRONMENT=Development
      - OPENAI_API_KEY=${OPENAI_API_KEY:-test-key}
    volumes:
      - ./backend:/home/site/wwwroot:ro
    depends_on:
      - azurite

volumes:
  azurite-data:
EOF

# Start containers
docker-compose up -d

# View logs
docker-compose logs -f functions

# Test function endpoint
curl http://localhost:7071/api/email/intake

# Stop containers
docker-compose down
```

## 4️⃣ Automated Test Script

### Create Comprehensive Test Script
```bash
# Save as test-all.sh in project root
cat > test-all.sh << 'EOF'
#!/bin/bash

echo "🧪 AI TenantShield - Comprehensive Local Testing"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "\n${CYAN}Testing: $test_name${NC}"
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        ((TESTS_FAILED++))
    fi
}

# Backend Tests
echo -e "\n${YELLOW}🔧 Backend Tests${NC}"
echo "=================="

run_test "PowerShell Module Manifest" \
    "pwsh -c 'Test-ModuleManifest ./backend/Modules/M365AIAgent/M365AIAgent.psd1'"

run_test "PowerShell Module Import" \
    "pwsh -c 'Import-Module ./backend/Modules/M365AIAgent/M365AIAgent.psd1 -Force'"

run_test "PowerShell Syntax Check" \
    "pwsh -c 'Get-ChildItem -Path ./backend -Recurse -Filter *.ps1 | ForEach-Object { \$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content \$_.FullName -Raw), [ref]\$null) }'"

# Mobile Tests
echo -e "\n${YELLOW}📱 Mobile Tests${NC}"
echo "==============="

if command -v swift &> /dev/null; then
    run_test "Swift Build" \
        "cd mobile && swift build"
    
    run_test "Swift Tests" \
        "cd mobile && swift test"
else
    echo -e "${YELLOW}⚠️  Swift not installed, skipping mobile tests${NC}"
fi

# Function App Tests
echo -e "\n${YELLOW}⚡ Azure Functions Tests${NC}"
echo "========================"

if command -v func &> /dev/null; then
    run_test "Function App Validation" \
        "cd backend && func host start --dry-run"
else
    echo -e "${YELLOW}⚠️  Azure Functions Core Tools not installed${NC}"
fi

# Summary
echo -e "\n${CYAN}================================${NC}"
echo -e "${CYAN}Test Summary${NC}"
echo -e "${CYAN}================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please review the output above.${NC}"
    exit 1
fi
EOF

chmod +x test-all.sh

# Run the test script
./test-all.sh
```

## 5️⃣ Manual Validation Checklist

### Backend Validation
- [ ] PowerShell module loads without errors
- [ ] All 14 exported functions are available
- [ ] Classes can be instantiated
- [ ] Module manifest is valid
- [ ] No syntax errors in PS1 files
- [ ] Unit tests run (even if some fail due to missing dependencies)

### Mobile Validation
- [ ] Swift package builds successfully
- [ ] No compilation errors
- [ ] Test suite runs
- [ ] Skip framework validates correctly

### Integration Validation
- [ ] Azure Functions start locally
- [ ] HTTP endpoints respond to requests
- [ ] JSON serialization works between PowerShell and Swift

## 6️⃣ Test Data Files

### Create Test Request File
```json
// Save as test-data/email-request.json
{
  "subject": "Urgent: Password Reset Required",
  "body": "Hello, I need to reset the password for user john.smith@contoso.com. They are locked out of their account and need access immediately. This is for the Contoso tenant.",
  "from": "helpdesk@contoso.com",
  "to": "support@msp.com",
  "tenant": "contoso-tenant-id",
  "clientName": "Contoso Corporation",
  "receivedDateTime": "2025-01-03T10:30:00Z",
  "messageId": "msg-12345"
}
```

### Create Test Approval File
```json
// Save as test-data/approval-request.json
{
  "Id": "550e8400-e29b-41d4-a716-446655440000",
  "TenantId": "contoso-tenant",
  "ClientName": "Contoso Corp",
  "RequestType": "password_reset",
  "Description": "Reset password for john.smith@contoso.com",
  "RiskScore": 30,
  "ProposedActions": [
    {
      "ActionType": "ResetPassword",
      "TargetResource": "john.smith@contoso.com",
      "CurrentState": {"passwordLastSet": "2024-01-01T00:00:00Z"},
      "ProposedState": {"passwordReset": true, "requireChangeOnLogin": true},
      "Description": "Reset user password and require change on next login"
    }
  ],
  "Status": "Pending",
  "ExpiresAt": "2025-01-03T11:00:00Z",
  "CreatedAt": "2025-01-03T10:30:00Z"
}
```

## 🚦 Expected Test Results

### ✅ What Should Work
- PowerShell module loading and class instantiation
- Swift compilation (with Skip installed)
- Azure Functions structure validation
- Unit tests with mocked dependencies
- Basic HTTP endpoint testing

### ⚠️ What May Fail (Expected)
- AI classification without valid OpenAI API key
- Service Bus operations (no Azure Service Bus)
- Key Vault operations (no Azure Key Vault)
- Graph API calls (no Microsoft Graph setup)
- Push notifications (no Azure Notification Hubs)

### ❌ What Requires Azure
- Full end-to-end workflow
- Real AI classification with OpenAI
- Mobile push notifications
- CIPP-API integration
- Audit logging to Azure Tables

## 📝 Quick Test Commands Reference

```bash
# Backend quick test
pwsh -c "Test-ModuleManifest ./backend/Modules/M365AIAgent/M365AIAgent.psd1"

# Mobile quick test
cd mobile && swift build && echo "✅ Mobile build successful"

# Functions quick test
cd backend && func host start --dry-run

# Run all tests
./test-all.sh
```

## 🔍 Troubleshooting

### Common Issues and Solutions

1. **Module Import Fails**
   ```powershell
   # Check PowerShell version
   $PSVersionTable.PSVersion
   # Should be 7.4 or higher
   ```

2. **Swift Build Fails**
   ```bash
   # Ensure Skip is installed
   skip checkup
   # Update Skip
   brew upgrade skiptools/skip/skip
   ```

3. **Functions Won't Start**
   ```bash
   # Check Node.js version
   node --version
   # Should be 18.x or higher
   
   # Reinstall Azure Functions Core Tools
   brew reinstall azure-functions-core-tools@4
   ```

4. **Tests Timeout**
   ```powershell
   # Increase timeout in test scripts
   $PSDefaultParameterValues['Invoke-Pester:Timeout'] = 120
   ```

## 📊 Test Coverage Goals

- **PowerShell Code**: >80% coverage
- **Swift Code**: >80% coverage
- **Integration Tests**: Core workflows covered
- **Security Tests**: Authentication and authorization
- **Performance Tests**: <2 minute approval workflow

---

**Last Updated**: January 2025
**Version**: 1.0.0
**Status**: Ready for local testing