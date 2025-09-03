# Skip Fuse Mobile Development Patterns

## Critical Skip Fuse Patterns for M365 AI Agent Mobile App

### Project Structure Pattern (MANDATORY)

```
M365AgentApp/
├── Sources/
│   └── M365AgentApp/
│       ├── M365AgentApp.swift         # App entry point
│       ├── Models/                    # Cross-platform data models
│       │   ├── ApprovalRequest.swift
│       │   ├── BiometricResult.swift  
│       │   └── RequestType.swift
│       ├── Views/                     # SwiftUI views (transpiled to Compose)
│       │   ├── ApprovalCardView.swift
│       │   ├── ApprovalListView.swift
│       │   └── BiometricView.swift
│       ├── Services/                  # Business logic
│       │   ├── ApprovalService.swift
│       │   ├── BiometricService.swift
│       │   └── APIClient.swift
│       └── Skip/                      # Skip configuration
│           └── skip.yml
├── Tests/
│   └── M365AgentAppTests/
├── Package.swift                      # Swift Package Manager
└── README.md
```

### Package.swift Configuration (MANDATORY)

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "M365AgentApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "M365AgentApp", targets: ["M365AgentApp"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "M365AgentApp",
            dependencies: [
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "SkipFoundation", package: "skip-foundation"),
            ],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .testTarget(
            name: "M365AgentAppTests",
            dependencies: ["M365AgentApp", .product(name: "SkipTest", package: "skip")]
        ),
    ]
)
```

### App Entry Point Pattern

```swift
// M365AgentApp.swift - CRITICAL structure for Skip transpilation
import SwiftUI
import SkipUI

@main
struct M365AgentApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var approvalService = ApprovalService()
    @StateObject private var biometricService = BiometricService()
    
    var body: some View {
        NavigationStack {
            ApprovalListView()
                .environmentObject(approvalService)
                .environmentObject(biometricService)
        }
    }
}
```

### Cross-Platform Data Models (CRITICAL)

```swift
// Models/ApprovalRequest.swift
import Foundation
import SkipFoundation

struct ApprovalRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let tenantId: String
    let requestType: RequestType
    let description: String
    let riskScore: Int
    let proposedActions: [ProposedAction]
    let context: RequestContext
    let expiresAt: Date
    let createdAt: Date
    
    // CRITICAL: Custom init for cross-platform compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        // ... other properties
        
        // GOTCHA: Date decoding must handle different formats
        let dateFormatter = ISO8601DateFormatter()
        let createdString = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = dateFormatter.date(from: createdString) ?? Date()
    }
}

// CRITICAL: Enum for request types (transpiles well to Android)
enum RequestType: String, Codable, CaseIterable {
    case passwordReset = "password_reset"
    case groupMembership = "group_membership"
    case userOnboarding = "user_onboarding"
    case userOffboarding = "user_offboarding"
    
    var displayName: String {
        switch self {
        case .passwordReset: return "Password Reset"
        case .groupMembership: return "Group Membership"
        case .userOnboarding: return "User Onboarding"
        case .userOffboarding: return "User Offboarding"
        }
    }
}
```

### Biometric Authentication Pattern (CRITICAL)

```swift
// Services/BiometricService.swift
import LocalAuthentication
import SkipFoundation

@MainActor
class BiometricService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var biometryType: LABiometryType = .none
    
    init() {
        checkBiometricAvailability()
    }
    
    // CRITICAL: Platform-specific implementations
    func authenticateForApproval(riskLevel: RiskLevel) async throws -> BiometricAuthResult {
        #if os(iOS)
        return try await authenticateWithiOS(riskLevel: riskLevel)
        #else
        // Skip transpiles this to Android biometric authentication
        return try await authenticateWithAndroid(riskLevel: riskLevel)
        #endif
    }
    
    private func authenticateWithiOS(riskLevel: RiskLevel) async throws -> BiometricAuthResult {
        let context = LAContext()
        
        // CRITICAL: Risk-based policy selection
        let policy: LAPolicy = switch riskLevel {
        case .low: .deviceOwnerAuthenticationWithBiometrics
        case .medium, .high: .deviceOwnerAuthentication // Requires passcode fallback
        }
        
        let reason = "Approve M365 administrative action"
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        let result = BiometricAuthResult(
                            success: true,
                            method: self?.biometryType ?? .none,
                            timestamp: Date(),
                            hash: self?.generateBiometricHash() ?? ""
                        )
                        continuation.resume(returning: result)
                    } else {
                        let biometricError = self?.mapLAError(error) ?? .authenticationFailed
                        continuation.resume(throwing: biometricError)
                    }
                }
            }
        }
    }
    
    // GOTCHA: Skip requires explicit Android implementation
    private func authenticateWithAndroid(riskLevel: RiskLevel) async throws -> BiometricAuthResult {
        // This gets transpiled to Android BiometricPrompt implementation
        fatalError("Skip will transpile this to Android implementation")
    }
    
    private func generateBiometricHash() -> String {
        // CRITICAL: Generate verifiable hash for audit trail
        let timestamp = Date().timeIntervalSince1970
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let hashInput = "\(deviceId)-\(timestamp)-biometric"
        return hashInput.sha256
    }
}

// CRITICAL: Biometric result model
struct BiometricAuthResult: Codable {
    let success: Bool
    let method: LABiometryType
    let timestamp: Date
    let hash: String
    
    enum CodingKeys: String, CodingKey {
        case success, method, timestamp, hash
    }
    
    // GOTCHA: LABiometryType doesn't conform to Codable by default
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(method.rawValue, forKey: .method)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(hash, forKey: .hash)
    }
}
```

### SwiftUI View Patterns (Cross-Platform)

```swift
// Views/ApprovalCardView.swift - CRITICAL: Skip-compatible SwiftUI
import SwiftUI
import SkipUI

struct ApprovalCardView: View {
    let request: ApprovalRequest
    let onApprove: () async throws -> Void
    let onReject: () async throws -> Void
    
    @State private var isProcessing = false
    @EnvironmentObject private var biometricService: BiometricService
    
    // CRITICAL: Risk-based color coding
    private var riskColor: Color {
        switch request.riskScore {
        case 0..<30: return .green
        case 30..<70: return .orange
        default: return .red
        }
    }
    
    private var riskLabel: String {
        switch request.riskScore {
        case 0..<30: return "LOW RISK"
        case 30..<70: return "MEDIUM RISK"
        default: return "HIGH RISK"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with risk indicator
            HStack {
                RiskBadge(score: request.riskScore, label: riskLabel, color: riskColor)
                Spacer()
                Text(request.context.clientName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Request description
            Text(request.description)
                .font(.headline)
                .foregroundColor(.primary)
            
            // CRITICAL: Before/After visualization
            if let proposedAction = request.proposedActions.first {
                BeforeAfterView(
                    currentState: proposedAction.currentState,
                    proposedState: proposedAction.proposedState
                )
            }
            
            // Expiration timer
            TimeRemainingView(expiresAt: request.expiresAt)
            
            // Action buttons
            HStack(spacing: 12) {
                ActionButton(
                    title: "Reject",
                    style: .secondary,
                    isLoading: isProcessing,
                    action: {
                        await handleReject()
                    }
                )
                
                ActionButton(
                    title: "Approve",
                    style: .primary,
                    isLoading: isProcessing,
                    action: {
                        await handleApprove()
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: riskColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    // CRITICAL: Biometric-protected approval flow
    private func handleApprove() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // CRITICAL: Biometric authentication before approval
            let riskLevel = RiskLevel(rawValue: request.riskScore)
            let biometricResult = try await biometricService.authenticateForApproval(riskLevel: riskLevel)
            
            // CRITICAL: Pass biometric proof to backend
            try await onApprove()
        } catch {
            // Handle biometric or approval errors
            print("Approval failed: \(error)")
        }
    }
    
    private func handleReject() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onReject()
        } catch {
            print("Rejection failed: \(error)")
        }
    }
}
```

### API Client Pattern (Cross-Platform)

```swift
// Services/APIClient.swift
import Foundation
import SkipFoundation

@MainActor  
class APIClient: ObservableObject {
    private let baseURL = URL(string: "https://your-azure-function-url.azurewebsites.net")!
    private let session: URLSession
    
    init() {
        // CRITICAL: Certificate pinning for production
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration, delegate: CertificatePinner(), delegateQueue: nil)
    }
    
    // CRITICAL: Generic async request method
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        // Add authentication headers
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // CRITICAL: Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // Approval request methods
    func getPendingApprovals() async throws -> [ApprovalRequest] {
        return try await performRequest(
            endpoint: "api/approvals/pending",
            responseType: [ApprovalRequest].self
        )
    }
    
    func submitApproval(
        requestId: UUID,
        approved: Bool,
        biometricResult: BiometricAuthResult
    ) async throws -> ApprovalResult {
        let body = ApprovalSubmission(
            requestId: requestId,
            approved: approved,
            biometricConfirmation: biometricResult,
            timestamp: Date()
        )
        
        let bodyData = try JSONEncoder.apiEncoder.encode(body)
        
        return try await performRequest(
            endpoint: "api/approvals/\(requestId)/submit",
            method: .POST,
            body: bodyData,
            responseType: ApprovalResult.self
        )
    }
}

// CRITICAL: Certificate pinning for security
class CertificatePinner: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Implement certificate pinning logic
        // GOTCHA: Skip may need special handling for Android certificate pinning
        completionHandler(.performDefaultHandling, nil)
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}
```

## Critical Skip Fuse Gotchas

### 1. Cross-Platform Compatibility
- Always use SkipUI instead of pure SwiftUI for views that need Android compatibility
- Test biometric authentication on both platforms separately
- Some iOS-specific APIs require explicit Android implementations

### 2. JSON Serialization
- Use custom Codable implementations for complex types
- Handle date formatting differences between platforms
- Test JSON compatibility with PowerShell backend thoroughly

### 3. Async/Await Patterns
- Use @MainActor for UI-related classes
- Wrap platform-specific async calls in withCheckedThrowingContinuation
- Handle cancellation properly in long-running operations

### 4. Build Configuration
- Skip requires specific Package.swift structure with plugin references
- Test both iOS simulator and Android emulator builds
- Use conditional compilation (#if os(iOS)) for platform-specific code

## Implementation Requirements

1. **MUST** use Skip-compatible SwiftUI patterns
2. **MUST** implement biometric authentication for both iOS and Android
3. **MUST** use proper async/await patterns with @MainActor
4. **MUST** implement certificate pinning for production security
5. **MUST** test JSON serialization compatibility with PowerShell backend
6. **MUST** handle network errors and offline scenarios gracefully