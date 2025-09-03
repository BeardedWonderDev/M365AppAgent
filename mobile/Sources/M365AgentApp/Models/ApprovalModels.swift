import Foundation
import SkipFoundation

// MARK: - Approval Request Model
struct ApprovalRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let tenantId: String
    let clientName: String
    let requestType: RequestType
    let description: String
    let riskScore: Int
    let proposedActions: [ProposedAction]
    let context: RequestContext
    let expiresAt: Date
    let createdAt: Date
    let status: ApprovalStatus
    
    // Custom init for cross-platform compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle UUID from string
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        
        self.tenantId = try container.decode(String.self, forKey: .tenantId)
        self.clientName = try container.decode(String.self, forKey: .clientName)
        self.requestType = try container.decode(RequestType.self, forKey: .requestType)
        self.description = try container.decode(String.self, forKey: .description)
        self.riskScore = try container.decode(Int.self, forKey: .riskScore)
        self.proposedActions = try container.decode([ProposedAction].self, forKey: .proposedActions)
        self.context = try container.decode(RequestContext.self, forKey: .context)
        
        // Handle date parsing from PowerShell format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let expiresString = try container.decode(String.self, forKey: .expiresAt)
        self.expiresAt = dateFormatter.date(from: expiresString) ?? Date()
        
        let createdString = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = dateFormatter.date(from: createdString) ?? Date()
        
        self.status = try container.decode(ApprovalStatus.self, forKey: .status)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(tenantId, forKey: .tenantId)
        try container.encode(clientName, forKey: .clientName)
        try container.encode(requestType, forKey: .requestType)
        try container.encode(description, forKey: .description)
        try container.encode(riskScore, forKey: .riskScore)
        try container.encode(proposedActions, forKey: .proposedActions)
        try container.encode(context, forKey: .context)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: expiresAt), forKey: .expiresAt)
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(status, forKey: .status)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case tenantId = "TenantId"
        case clientName = "ClientName"
        case requestType = "RequestType"
        case description = "Description"
        case riskScore = "RiskScore"
        case proposedActions = "ProposedActions"
        case context = "Context"
        case expiresAt = "ExpiresAt"
        case createdAt = "CreatedAt"
        case status = "Status"
    }
}

// MARK: - Request Type Enum
enum RequestType: String, Codable, CaseIterable {
    case passwordReset = "password_reset"
    case groupMembership = "group_membership"
    case userOnboarding = "user_onboarding"
    case userOffboarding = "user_offboarding"
    case permissionChange = "permission_change"
    case licenseAssignment = "license_assignment"
    case securityGroupChange = "security_group_change"
    case conditionalAccessChange = "conditional_access_change"
    
    var displayName: String {
        switch self {
        case .passwordReset: return "Password Reset"
        case .groupMembership: return "Group Membership"
        case .userOnboarding: return "User Onboarding"
        case .userOffboarding: return "User Offboarding"
        case .permissionChange: return "Permission Change"
        case .licenseAssignment: return "License Assignment"
        case .securityGroupChange: return "Security Group Change"
        case .conditionalAccessChange: return "Conditional Access"
        }
    }
    
    var icon: String {
        switch self {
        case .passwordReset: return "key.fill"
        case .groupMembership: return "person.3.fill"
        case .userOnboarding: return "person.badge.plus"
        case .userOffboarding: return "person.badge.minus"
        case .permissionChange: return "lock.shield.fill"
        case .licenseAssignment: return "doc.badge.plus"
        case .securityGroupChange: return "shield.fill"
        case .conditionalAccessChange: return "lock.rotation"
        }
    }
}

// MARK: - Approval Status
enum ApprovalStatus: String, Codable {
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
    case expired = "Expired"
    case autoApproved = "AutoApproved"
    case autoRejected = "AutoRejected"
}

// MARK: - Risk Level
enum RiskLevel: Int, Codable, Comparable {
    case low = 0
    case medium = 30
    case high = 70
    case critical = 90
    
    init(score: Int) {
        switch score {
        case 0..<30: self = .low
        case 30..<70: self = .medium
        case 70..<90: self = .high
        default: self = .critical
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
    
    var label: String {
        switch self {
        case .low: return "LOW RISK"
        case .medium: return "MEDIUM RISK"
        case .high: return "HIGH RISK"
        case .critical: return "CRITICAL RISK"
        }
    }
    
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Proposed Action
struct ProposedAction: Codable, Identifiable {
    let id = UUID()
    let actionType: String
    let targetResource: String
    let currentState: [String: String]
    let proposedState: [String: String]
    let graphAPIEndpoint: String
    let graphAPIBody: [String: Any]?
    let description: String
    let impact: String
    
    private enum CodingKeys: String, CodingKey {
        case actionType = "ActionType"
        case targetResource = "TargetResource"
        case currentState = "CurrentState"
        case proposedState = "ProposedState"
        case graphAPIEndpoint = "GraphAPIEndpoint"
        case graphAPIBody = "GraphAPIBody"
        case description = "Description"
        case impact = "Impact"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actionType = try container.decode(String.self, forKey: .actionType)
        self.targetResource = try container.decode(String.self, forKey: .targetResource)
        self.currentState = try container.decodeIfPresent([String: String].self, forKey: .currentState) ?? [:]
        self.proposedState = try container.decodeIfPresent([String: String].self, forKey: .proposedState) ?? [:]
        self.graphAPIEndpoint = try container.decode(String.self, forKey: .graphAPIEndpoint)
        
        // Handle PowerShell hashtable as dictionary
        if let bodyData = try? container.decode([String: AnyCodable].self, forKey: .graphAPIBody) {
            self.graphAPIBody = bodyData.mapValues { $0.value }
        } else {
            self.graphAPIBody = nil
        }
        
        self.description = try container.decode(String.self, forKey: .description)
        self.impact = try container.decode(String.self, forKey: .impact)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionType, forKey: .actionType)
        try container.encode(targetResource, forKey: .targetResource)
        try container.encode(currentState, forKey: .currentState)
        try container.encode(proposedState, forKey: .proposedState)
        try container.encode(graphAPIEndpoint, forKey: .graphAPIEndpoint)
        
        if let body = graphAPIBody {
            let codableBody = body.mapValues { AnyCodable($0) }
            try container.encode(codableBody, forKey: .graphAPIBody)
        }
        
        try container.encode(description, forKey: .description)
        try container.encode(impact, forKey: .impact)
    }
}

// MARK: - Request Context
struct RequestContext: Codable {
    let originalRequestContent: String
    let requestSource: String
    let clientName: String
    let tenantId: String
    let requestorEmail: String?
    let requestorName: String?
    let currentState: [String: String]
    let additionalMetadata: [String: String]
    let detectedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case originalRequestContent = "OriginalRequestContent"
        case requestSource = "RequestSource"
        case clientName = "ClientName"
        case tenantId = "TenantId"
        case requestorEmail = "RequestorEmail"
        case requestorName = "RequestorName"
        case currentState = "CurrentState"
        case additionalMetadata = "AdditionalMetadata"
        case detectedAt = "DetectedAt"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalRequestContent = try container.decode(String.self, forKey: .originalRequestContent)
        self.requestSource = try container.decode(String.self, forKey: .requestSource)
        self.clientName = try container.decode(String.self, forKey: .clientName)
        self.tenantId = try container.decode(String.self, forKey: .tenantId)
        self.requestorEmail = try container.decodeIfPresent(String.self, forKey: .requestorEmail)
        self.requestorName = try container.decodeIfPresent(String.self, forKey: .requestorName)
        self.currentState = try container.decodeIfPresent([String: String].self, forKey: .currentState) ?? [:]
        self.additionalMetadata = try container.decodeIfPresent([String: String].self, forKey: .additionalMetadata) ?? [:]
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let detectedString = try container.decode(String.self, forKey: .detectedAt)
        self.detectedAt = dateFormatter.date(from: detectedString) ?? Date()
    }
}

// MARK: - Biometric Confirmation
struct BiometricConfirmation: Codable {
    let success: Bool
    let method: String
    let timestamp: Date
    let hash: String
    let deviceId: String
    let platform: String
    
    private enum CodingKeys: String, CodingKey {
        case success = "Success"
        case method = "Method"
        case timestamp = "Timestamp"
        case hash = "Hash"
        case deviceId = "DeviceId"
        case platform = "Platform"
    }
}

// MARK: - Approval Submission
struct ApprovalSubmission: Codable {
    let requestId: UUID
    let approved: Bool
    let biometricConfirmation: BiometricAuthResult
    let timestamp: Date
    let notes: String?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestId.uuidString, forKey: .requestId)
        try container.encode(approved, forKey: .approved)
        try container.encode(biometricConfirmation, forKey: .biometricConfirmation)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: timestamp), forKey: .timestamp)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestId = "RequestId"
        case approved = "Approved"
        case biometricConfirmation = "BiometricConfirmation"
        case timestamp = "Timestamp"
        case notes = "Notes"
    }
}

// MARK: - Approval Result
struct ApprovalResult: Codable {
    let requestId: String
    let success: Bool
    let status: String
    let message: String
    let executionResults: [ExecutionResult]
    let completedAt: Date
    let auditLogId: String
    
    private enum CodingKeys: String, CodingKey {
        case requestId = "RequestId"
        case success = "Success"
        case status = "Status"
        case message = "Message"
        case executionResults = "ExecutionResults"
        case completedAt = "CompletedAt"
        case auditLogId = "AuditLogId"
    }
}

// MARK: - Execution Result
struct ExecutionResult: Codable {
    let actionType: String
    let success: Bool
    let targetResource: String
    let resultMessage: String
    let httpStatusCode: Int
    let executedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case actionType = "ActionType"
        case success = "Success"
        case targetResource = "TargetResource"
        case resultMessage = "ResultMessage"
        case httpStatusCode = "HttpStatusCode"
        case executedAt = "ExecutedAt"
    }
}

// MARK: - Biometric Auth Result
struct BiometricAuthResult: Codable {
    let success: Bool
    let method: BiometryType
    let timestamp: Date
    let hash: String
    
    enum BiometryType: Int, Codable {
        case none = 0
        case touchID = 1
        case faceID = 2
        case opticID = 3
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(method.displayName, forKey: .method)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: timestamp), forKey: .timestamp)
        try container.encode(hash, forKey: .hash)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success = "Success"
        case method = "Method"
        case timestamp = "Timestamp"
        case hash = "Hash"
    }
}

// MARK: - Helper for Any Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}