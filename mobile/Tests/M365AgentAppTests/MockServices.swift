import Foundation
import LocalAuthentication
import CryptoKit
@testable import M365AgentApp

/**
 * Mock service implementations for comprehensive testing of M365AgentApp
 * 
 * Provides mock implementations for:
 * - APIClient with configurable network responses
 * - ApprovalService with controllable state management
 * - NotificationService with simulated push notifications
 * - BiometricService with mock authentication flows
 * 
 * Supports cross-platform testing through Skip Fuse patterns
 * Enables testing of error conditions, network failures, and edge cases
 * 
 * @author AI TenantShield Development Team
 * @version 1.0.0
 * @since 2025-09-03
 */

// MARK: - Mock API Client

/// Mock implementation of APIClient for testing network operations
class MockAPIClient: APIClientProtocol {
    
    // MARK: - Properties
    
    var baseURL: URL
    var mockResponses: [String: MockAPIResponse] = [:]
    var networkDelay: TimeInterval = 0.1
    var shouldFailNextRequest = false
    var lastRequestURL: URL?
    var lastRequestMethod: String?
    var lastRequestHeaders: [String: String] = [:]
    var lastRequestBody: Data?
    
    // MARK: - Initialization
    
    init(baseURL: URL = URL(string: "https://mock-api.test.com")!) {
        self.baseURL = baseURL
        setupDefaultMockResponses()
    }
    
    // MARK: - APIClientProtocol Implementation
    
    func fetchPendingApprovals() async throws -> [ApprovalRequest] {
        let response = try await performMockRequest(
            endpoint: "/api/approvals/pending",
            method: "GET"
        )
        
        return try JSONDecoder().decode([ApprovalRequest].self, from: response)
    }
    
    func submitApprovalDecision(_ submission: ApprovalSubmission) async throws -> ApprovalResult {
        let submissionData = try JSONEncoder().encode(submission)
        
        let response = try await performMockRequest(
            endpoint: "/api/approvals/submit",
            method: "POST",
            body: submissionData
        )
        
        return try JSONDecoder().decode(ApprovalResult.self, from: response)
    }
    
    func fetchApprovalDetails(requestId: UUID) async throws -> ApprovalRequest {
        let response = try await performMockRequest(
            endpoint: "/api/approvals/\(requestId.uuidString)",
            method: "GET"
        )
        
        return try JSONDecoder().decode(ApprovalRequest.self, from: response)
    }
    
    // MARK: - Mock Configuration Methods
    
    func setMockResponse(for endpoint: String, response: MockAPIResponse) {
        mockResponses[endpoint] = response
    }
    
    func setNetworkDelay(_ delay: TimeInterval) {
        networkDelay = delay
    }
    
    func simulateNetworkFailure() {
        shouldFailNextRequest = true
    }
    
    func clearMockResponses() {
        mockResponses.removeAll()
        setupDefaultMockResponses()
    }
    
    // MARK: - Private Methods
    
    private func performMockRequest(
        endpoint: String,
        method: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        
        // Store request details for verification
        lastRequestURL = URL(string: endpoint, relativeTo: baseURL)
        lastRequestMethod = method
        lastRequestHeaders = headers
        lastRequestBody = body
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        
        // Simulate network failure if configured
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw APIError.networkError
        }
        
        // Find mock response
        guard let mockResponse = mockResponses[endpoint] else {
            throw APIError.invalidResponse
        }
        
        // Simulate error if configured
        if let error = mockResponse.error {
            throw error
        }
        
        // Return mock data
        return mockResponse.data
    }
    
    private func setupDefaultMockResponses() {
        // Default empty pending approvals
        mockResponses["/api/approvals/pending"] = MockAPIResponse(
            data: try! JSONEncoder().encode([ApprovalRequest]())
        )
        
        // Default successful submission
        let defaultResult = ApprovalResult(
            requestId: UUID().uuidString,
            success: true,
            status: "Approved",
            message: "Mock approval completed",
            executionResults: [],
            completedAt: Date(),
            auditLogId: "mock-audit-123"
        )
        
        mockResponses["/api/approvals/submit"] = MockAPIResponse(
            data: try! JSONEncoder().encode(defaultResult)
        )
    }
}

// MARK: - Mock Approval Service

/// Mock implementation of ApprovalService for testing business logic
@Observable
class MockApprovalService: ApprovalServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var pendingRequests: [ApprovalRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Mock Configuration
    
    var shouldFailOperations = false
    var operationDelay: TimeInterval = 0.1
    var mockPendingRequests: [ApprovalRequest] = []
    
    private let apiClient: MockAPIClient
    private let biometricService: MockBiometricService
    
    // MARK: - Initialization
    
    init(
        apiClient: MockAPIClient = MockAPIClient(),
        biometricService: MockBiometricService = MockBiometricService()
    ) {
        self.apiClient = apiClient
        self.biometricService = biometricService
    }
    
    // MARK: - ApprovalServiceProtocol Implementation
    
    func loadPendingRequests() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
            
            if shouldFailOperations {
                throw APIError.networkError
            }
            
            pendingRequests = mockPendingRequests
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func approveRequest(
        _ request: ApprovalRequest,
        biometricConfirmation: BiometricAuthResult
    ) async throws -> ApprovalResult {
        
        if shouldFailOperations {
            throw APIError.unauthorized
        }
        
        try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        
        // Remove from pending requests
        pendingRequests.removeAll { $0.id == request.id }
        
        return ApprovalResult(
            requestId: request.id.uuidString,
            success: true,
            status: "Approved",
            message: "Mock approval successful",
            executionResults: [
                ExecutionResult(
                    actionType: request.requestType.rawValue,
                    success: true,
                    targetResource: "mock-target",
                    resultMessage: "Mock execution completed",
                    httpStatusCode: 200,
                    executedAt: Date()
                )
            ],
            completedAt: Date(),
            auditLogId: "mock-audit-\(UUID().uuidString)"
        )
    }
    
    func rejectRequest(
        _ request: ApprovalRequest,
        biometricConfirmation: BiometricAuthResult,
        reason: String?
    ) async throws -> ApprovalResult {
        
        if shouldFailOperations {
            throw APIError.unauthorized
        }
        
        try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        
        // Remove from pending requests
        pendingRequests.removeAll { $0.id == request.id }
        
        return ApprovalResult(
            requestId: request.id.uuidString,
            success: true,
            status: "Rejected",
            message: reason ?? "Request rejected",
            executionResults: [],
            completedAt: Date(),
            auditLogId: "mock-audit-\(UUID().uuidString)"
        )
    }
    
    func handleExpiredRequests() async {
        let expiredRequests = pendingRequests.filter { $0.expiresAt < Date() }
        
        for request in expiredRequests {
            pendingRequests.removeAll { $0.id == request.id }
        }
    }
    
    // MARK: - Mock Configuration Methods
    
    func setMockPendingRequests(_ requests: [ApprovalRequest]) {
        mockPendingRequests = requests
    }
    
    func addMockPendingRequest(_ request: ApprovalRequest) {
        mockPendingRequests.append(request)
    }
    
    func setOperationDelay(_ delay: TimeInterval) {
        operationDelay = delay
    }
    
    func simulateFailure(_ shouldFail: Bool = true) {
        shouldFailOperations = shouldFail
    }
}

// MARK: - Mock Biometric Service

/// Mock implementation of BiometricService for testing authentication flows
@Observable 
class MockBiometricService: BiometricServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var biometryType: LABiometryType = .none
    @Published var isBiometricAvailable: Bool = true
    @Published var lastAuthResult: BiometricAuthResult?
    
    // MARK: - Mock Configuration
    
    var shouldAuthenticateSuccessfully = true
    var mockBiometryType: LABiometryType = .faceID
    var authenticationDelay: TimeInterval = 0.5
    var simulatedError: BiometricError?
    
    // MARK: - Initialization
    
    init() {
        biometryType = mockBiometryType
    }
    
    // MARK: - BiometricServiceProtocol Implementation
    
    func updateBiometricStatus() {
        biometryType = mockBiometryType
        isBiometricAvailable = true
    }
    
    func authenticateForApproval(
        riskLevel: RiskLevel,
        reason: String = "Mock biometric authentication"
    ) async throws -> BiometricAuthResult {
        
        try await Task.sleep(nanoseconds: UInt64(authenticationDelay * 1_000_000_000))
        
        // Simulate configured error
        if let error = simulatedError {
            simulatedError = nil // Reset after use
            throw error
        }
        
        // Simulate authentication result
        if shouldAuthenticateSuccessfully {
            let result = BiometricAuthResult(
                success: true,
                method: mapLABiometryToBiometryType(mockBiometryType),
                timestamp: Date(),
                hash: generateMockHash()
            )
            
            lastAuthResult = result
            return result
        } else {
            throw BiometricError.authenticationFailed
        }
    }
    
    func generateAuditHash(for authResult: BiometricAuthResult) -> String {
        return generateMockHash()
    }
    
    func createAuditLogEntry(
        for result: BiometricAuthResult,
        riskLevel: RiskLevel,
        requestId: UUID
    ) -> [String: Any] {
        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "requestId": requestId.uuidString,
            "deviceId": "mock-device-123",
            "platform": "iOS-Mock",
            "biometricMethod": result.method.displayName,
            "authenticationSuccess": result.success,
            "riskLevel": riskLevel.label,
            "auditHash": result.hash
        ]
    }
    
    // MARK: - Mock Configuration Methods
    
    func setMockBiometryType(_ type: LABiometryType) {
        mockBiometryType = type
        biometryType = type
    }
    
    func setAuthenticationSuccess(_ success: Bool) {
        shouldAuthenticateSuccessfully = success
    }
    
    func setAuthenticationDelay(_ delay: TimeInterval) {
        authenticationDelay = delay
    }
    
    func simulateError(_ error: BiometricError) {
        simulatedError = error
    }
    
    func simulateBiometryUnavailable() {
        isBiometricAvailable = false
        biometryType = .none
    }
    
    // MARK: - Private Methods
    
    private func mapLABiometryToBiometryType(_ laBiometry: LABiometryType) -> BiometricAuthResult.BiometryType {
        switch laBiometry {
        case .none: return .none
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        @unknown default: return .none
        }
    }
    
    private func generateMockHash() -> String {
        let data = "mock-biometric-\(Date().timeIntervalSince1970)".data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Mock Notification Service

/// Mock implementation of NotificationService for testing push notifications
@Observable
class MockNotificationService: NotificationServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var isRegistered: Bool = false
    @Published var deviceToken: Data?
    @Published var lastNotificationPayload: [String: Any]?
    
    // MARK: - Mock Configuration
    
    var shouldFailRegistration = false
    var registrationDelay: TimeInterval = 0.2
    var receivedNotifications: [[String: Any]] = []
    
    // MARK: - Callback Properties
    
    var onNotificationReceived: (([String: Any]) -> Void)?
    
    // MARK: - NotificationServiceProtocol Implementation
    
    func registerForNotifications(deviceToken: Data) async throws -> Bool {
        try await Task.sleep(nanoseconds: UInt64(registrationDelay * 1_000_000_000))
        
        if shouldFailRegistration {
            throw NotificationError.registrationFailed
        }
        
        self.deviceToken = deviceToken
        isRegistered = true
        return true
    }
    
    func handleNotification(payload: [String: Any]) async {
        lastNotificationPayload = payload
        receivedNotifications.append(payload)
        onNotificationReceived?(payload)
    }
    
    func requestNotificationPermissions() async -> Bool {
        // Mock always grants permission
        return true
    }
    
    // MARK: - Mock Configuration Methods
    
    func setRegistrationFailure(_ shouldFail: Bool = true) {
        shouldFailRegistration = shouldFail
    }
    
    func setRegistrationDelay(_ delay: TimeInterval) {
        registrationDelay = delay
    }
    
    func simulateNotificationReceived(payload: [String: Any]) async {
        await handleNotification(payload: payload)
    }
    
    func clearReceivedNotifications() {
        receivedNotifications.removeAll()
        lastNotificationPayload = nil
    }
}

// MARK: - Mock View Model

/// Mock implementation of ApprovalViewModel for testing UI state management
@Observable
class MockApprovalViewModel: ApprovalViewModelProtocol {
    
    // MARK: - Published Properties
    
    @Published var pendingRequests: [ApprovalRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedRequest: ApprovalRequest?
    
    // MARK: - Mock Configuration
    
    var shouldSimulateLoading = true
    var mockRequests: [ApprovalRequest] = []
    
    private let approvalService: MockApprovalService
    
    // MARK: - Initialization
    
    init(approvalService: MockApprovalService = MockApprovalService()) {
        self.approvalService = approvalService
    }
    
    // MARK: - ApprovalViewModelProtocol Implementation
    
    func loadPendingRequests() async {
        if shouldSimulateLoading {
            isLoading = true
        }
        
        await approvalService.loadPendingRequests()
        
        pendingRequests = approvalService.pendingRequests
        errorMessage = approvalService.errorMessage
        isLoading = false
    }
    
    func approveRequest(_ request: ApprovalRequest, biometricAuth: BiometricAuthResult) async -> Bool {
        do {
            _ = try await approvalService.approveRequest(request, biometricConfirmation: biometricAuth)
            pendingRequests.removeAll { $0.id == request.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func rejectRequest(_ request: ApprovalRequest, biometricAuth: BiometricAuthResult, reason: String?) async -> Bool {
        do {
            _ = try await approvalService.rejectRequest(request, biometricConfirmation: biometricAuth, reason: reason)
            pendingRequests.removeAll { $0.id == request.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func selectRequest(_ request: ApprovalRequest?) {
        selectedRequest = request
    }
    
    // MARK: - Mock Configuration Methods
    
    func setMockRequests(_ requests: [ApprovalRequest]) {
        mockRequests = requests
        approvalService.setMockPendingRequests(requests)
    }
    
    func simulateLoadingState(_ simulate: Bool = true) {
        shouldSimulateLoading = simulate
    }
}

// MARK: - Supporting Types and Protocols

/// Protocol for API client to enable mocking
protocol APIClientProtocol {
    var baseURL: URL { get }
    
    func fetchPendingApprovals() async throws -> [ApprovalRequest]
    func submitApprovalDecision(_ submission: ApprovalSubmission) async throws -> ApprovalResult
    func fetchApprovalDetails(requestId: UUID) async throws -> ApprovalRequest
}

/// Protocol for approval service to enable mocking
protocol ApprovalServiceProtocol {
    var pendingRequests: [ApprovalRequest] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func loadPendingRequests() async
    func approveRequest(_ request: ApprovalRequest, biometricConfirmation: BiometricAuthResult) async throws -> ApprovalResult
    func rejectRequest(_ request: ApprovalRequest, biometricConfirmation: BiometricAuthResult, reason: String?) async throws -> ApprovalResult
    func handleExpiredRequests() async
}

/// Protocol for biometric service to enable mocking
protocol BiometricServiceProtocol {
    var biometryType: LABiometryType { get }
    var isBiometricAvailable: Bool { get }
    var lastAuthResult: BiometricAuthResult? { get }
    
    func updateBiometricStatus()
    func authenticateForApproval(riskLevel: RiskLevel, reason: String) async throws -> BiometricAuthResult
    func generateAuditHash(for authResult: BiometricAuthResult) -> String
    func createAuditLogEntry(for result: BiometricAuthResult, riskLevel: RiskLevel, requestId: UUID) -> [String: Any]
}

/// Protocol for notification service to enable mocking
protocol NotificationServiceProtocol {
    var isRegistered: Bool { get }
    var deviceToken: Data? { get }
    
    func registerForNotifications(deviceToken: Data) async throws -> Bool
    func handleNotification(payload: [String: Any]) async
    func requestNotificationPermissions() async -> Bool
}

/// Protocol for approval view model to enable mocking
protocol ApprovalViewModelProtocol {
    var pendingRequests: [ApprovalRequest] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var selectedRequest: ApprovalRequest? { get }
    
    func loadPendingRequests() async
    func approveRequest(_ request: ApprovalRequest, biometricAuth: BiometricAuthResult) async -> Bool
    func rejectRequest(_ request: ApprovalRequest, biometricAuth: BiometricAuthResult, reason: String?) async -> Bool
    func selectRequest(_ request: ApprovalRequest?)
}

/// Mock API response structure
struct MockAPIResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
    let error: Error?
    
    init(data: Data, statusCode: Int = 200, headers: [String: String] = [:], error: Error? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.error = error
    }
}

/// API errors for testing
enum APIError: LocalizedError {
    case networkError
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

/// Notification errors for testing
enum NotificationError: LocalizedError {
    case registrationFailed
    case permissionDenied
    case invalidPayload
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register for notifications"
        case .permissionDenied:
            return "Notification permission denied"
        case .invalidPayload:
            return "Invalid notification payload"
        }
    }
}

// MARK: - Test Data Factory

/// Factory for creating test data
struct TestDataFactory {
    
    static func createMockApprovalRequest(
        requestType: RequestType = .passwordReset,
        riskScore: Int = 25,
        status: ApprovalStatus = .pending
    ) -> ApprovalRequest {
        
        let context = RequestContext(
            originalRequestContent: "Test request content",
            requestSource: "test",
            clientName: "Test Client",
            tenantId: "test-tenant-123",
            requestorEmail: "test@example.com",
            requestorName: "Test User",
            currentState: [:],
            additionalMetadata: [:],
            detectedAt: Date()
        )
        
        return ApprovalRequest(
            id: UUID(),
            tenantId: "test-tenant-123",
            clientName: "Test Client",
            requestType: requestType,
            description: "Test \(requestType.displayName) request",
            riskScore: riskScore,
            proposedActions: [],
            context: context,
            expiresAt: Date().addingTimeInterval(1800), // 30 minutes
            createdAt: Date(),
            status: status
        )
    }
    
    static func createMockBiometricAuthResult(
        success: Bool = true,
        method: BiometricAuthResult.BiometryType = .faceID
    ) -> BiometricAuthResult {
        return BiometricAuthResult(
            success: success,
            method: method,
            timestamp: Date(),
            hash: "mock-hash-\(UUID().uuidString.prefix(8))"
        )
    }
    
    static func createMockApprovalSubmission(
        requestId: UUID = UUID(),
        approved: Bool = true
    ) -> ApprovalSubmission {
        return ApprovalSubmission(
            requestId: requestId,
            approved: approved,
            biometricConfirmation: createMockBiometricAuthResult(),
            timestamp: Date(),
            notes: approved ? "Approved via test" : "Rejected via test"
        )
    }
    
    static func createMockNotificationPayload(
        requestId: UUID = UUID(),
        requestType: RequestType = .passwordReset,
        riskScore: Int = 25
    ) -> [String: Any] {
        return [
            "requestId": requestId.uuidString,
            "requestType": requestType.rawValue,
            "clientName": "Test Client",
            "riskScore": riskScore,
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(1800)),
            "description": "Test notification"
        ]
    }
}