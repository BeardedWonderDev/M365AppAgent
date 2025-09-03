import SwiftUI
import SkipUI

/// SwiftUI approval interface with risk visualization and biometric-protected approval/rejection
/// Displays before/after state comparison with risk-appropriate color coding and controls
public struct ApprovalCardView: View {
    
    // MARK: - Properties
    
    let request: ApprovalRequest
    @ObservedObject private var biometricService: BiometricService
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var approvalResult: ApprovalResult?
    
    // Callbacks for parent view
    let onApprove: (ApprovalSubmission) -> Void
    let onReject: (ApprovalSubmission) -> Void
    let onExpired: () -> Void
    
    // Timer for expiration countdown
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    // MARK: - Computed Properties
    
    private var riskLevel: RiskLevel {
        return RiskLevel(score: request.riskScore)
    }
    
    private var riskColor: Color {
        switch riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private var isExpired: Bool {
        return Date() > request.expiresAt
    }
    
    private var formattedTimeRemaining: String {
        if timeRemaining <= 0 {
            return "EXPIRED"
        }
        
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Initialization
    
    public init(
        request: ApprovalRequest,
        biometricService: BiometricService,
        onApprove: @escaping (ApprovalSubmission) -> Void,
        onReject: @escaping (ApprovalSubmission) -> Void,
        onExpired: @escaping () -> Void = {}
    ) {
        self.request = request
        self.biometricService = biometricService
        self.onApprove = onApprove
        self.onReject = onReject
        self.onExpired = onExpired
    }
    
    // MARK: - Body
    
    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                // Header with risk indicator and client info
                headerSection
                
                // Request details
                requestDetailsSection
                
                // Before/After state visualization
                if let firstAction = request.proposedActions.first {
                    beforeAfterSection(action: firstAction)
                }
                
                // Expiration timer
                expirationSection
                
                // Action buttons or status
                if isExpired {
                    expiredSection
                } else if request.status == .pending {
                    actionButtonsSection
                } else {
                    statusSection
                }
            }
            .padding()
        }
        .opacity(isExpired ? 0.6 : 1.0)
        .onAppear {
            startExpirationTimer()
        }
        .onDisappear {
            stopExpirationTimer()
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Request Processed", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            if let result = approvalResult {
                Text(result.message)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Risk badge with color coding
            RiskBadge(level: riskLevel, color: riskColor)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(request.clientName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(request.tenantId.prefix(8) + "...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Request Details Section
    
    private var requestDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Request type with icon
            HStack {
                Image(systemName: request.requestType.icon)
                    .foregroundColor(riskColor)
                
                Text(request.requestType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // Description
            Text(request.description)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Source information
            if !request.context.requestorName.isNilOrEmpty {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.secondary)
                    
                    Text("Requested by: \(request.context.requestorName ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Before/After Section
    
    private func beforeAfterSection(action: ProposedAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposed Changes")
                .font(.headline)
                .fontWeight(.medium)
            
            HStack(alignment: .top, spacing: 16) {
                // Current State (Before)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Current", systemImage: "minus.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    StateDisplayView(
                        state: action.currentState,
                        color: .secondary
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Arrow
                Image(systemName: "arrow.right")
                    .foregroundColor(riskColor)
                    .font(.title2)
                
                // Proposed State (After)
                VStack(alignment: .leading, spacing: 8) {
                    Label("After", systemImage: "plus.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(riskColor)
                    
                    StateDisplayView(
                        state: action.proposedState,
                        color: riskColor
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Impact description
            if !action.impact.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Impact: \(action.impact)")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Expiration Section
    
    private var expirationSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(timeRemaining < 60 ? .red : .secondary)
            
            Text("Expires in: \(formattedTimeRemaining)")
                .font(.caption)
                .fontWeight(timeRemaining < 60 ? .bold : .regular)
                .foregroundColor(timeRemaining < 60 ? .red : .secondary)
            
            Spacer()
            
            // Request timestamp
            Text("Received: \(formatTimestamp(request.createdAt))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Biometric status indicator
            if !biometricService.isBiometricAvailable {
                BiometricUnavailableWarning()
            }
            
            HStack(spacing: 16) {
                // Reject Button
                Button(action: {
                    Task {
                        await handleRejection()
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                
                // Approve Button
                Button(action: {
                    Task {
                        await handleApproval()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isProcessing ? "Authenticating..." : "Approve")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(riskColor.opacity(0.1))
                    .foregroundColor(riskColor)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(riskColor.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing || !biometricService.isBiometricAvailable)
            }
            
            // Risk warning for high-risk actions
            if riskLevel.rawValue >= RiskLevel.high.rawValue {
                RiskWarningView(riskLevel: riskLevel)
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(request.status.rawValue)
                .font(.headline)
                .foregroundColor(statusColor)
            
            Spacer()
            
            if request.status == .approved || request.status == .rejected {
                Text("Processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Expired Section
    
    private var expiredSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.xmark")
                    .foregroundColor(.red)
                
                Text("Request Expired")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
            }
            
            Text("This approval request has expired and can no longer be processed.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties for Status
    
    private var statusIcon: String {
        switch request.status {
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .expired: return "clock.badge.xmark"
        case .autoApproved: return "checkmark.circle"
        case .autoRejected: return "xmark.circle"
        case .pending: return "clock"
        }
    }
    
    private var statusColor: Color {
        switch request.status {
        case .approved, .autoApproved: return .green
        case .rejected, .autoRejected: return .red
        case .expired: return .orange
        case .pending: return .blue
        }
    }
    
    // MARK: - Actions
    
    private func handleApproval() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        do {
            // Perform biometric authentication
            let authResult = try await biometricService.authenticateForApproval(
                riskLevel: riskLevel,
                reason: "Approve \(request.requestType.displayName) for \(request.clientName)"
            )
            
            // Create approval submission
            let submission = ApprovalSubmission(
                requestId: request.id,
                approved: true,
                biometricConfirmation: authResult,
                timestamp: Date(),
                notes: nil
            )
            
            // Call parent handler
            onApprove(submission)
            
        } catch let error as BiometricError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
            showingError = true
        }
        
        isProcessing = false
    }
    
    private func handleRejection() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        do {
            // Even rejections require biometric confirmation for audit trail
            let authResult = try await biometricService.authenticateForApproval(
                riskLevel: .low, // Lower security for rejection
                reason: "Reject \(request.requestType.displayName) for \(request.clientName)"
            )
            
            // Create rejection submission
            let submission = ApprovalSubmission(
                requestId: request.id,
                approved: false,
                biometricConfirmation: authResult,
                timestamp: Date(),
                notes: nil
            )
            
            // Call parent handler
            onReject(submission)
            
        } catch let error as BiometricError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
            showingError = true
        }
        
        isProcessing = false
    }
    
    // MARK: - Timer Management
    
    private func startExpirationTimer() {
        updateTimeRemaining()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
            
            if timeRemaining <= 0 {
                stopExpirationTimer()
                onExpired()
            }
        }
    }
    
    private func stopExpirationTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, request.expiresAt.timeIntervalSinceNow)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

/// Risk badge with color-coded risk level indicator
struct RiskBadge: View {
    let level: RiskLevel
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(level.label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Display current vs proposed state with key-value pairs
struct StateDisplayView: View {
    let state: [String: String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(state.keys.sorted()), id: \.self) { key in
                HStack {
                    Text("\(key):")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(state[key] ?? "")
                        .font(.caption2)
                        .foregroundColor(color)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.05))
        .cornerRadius(6)
    }
}

/// Warning view for high-risk operations
struct RiskWarningView: View {
    let riskLevel: RiskLevel
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(warningText)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var warningText: String {
        switch riskLevel {
        case .high:
            return "HIGH RISK: This action may significantly impact the tenant. Verify carefully before approving."
        case .critical:
            return "CRITICAL RISK: This action could cause major disruption. Ensure authorization and backup plans."
        default:
            return "Please verify this action is authorized before approving."
        }
    }
}

/// Warning when biometric authentication is not available
struct BiometricUnavailableWarning: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text("Biometric authentication is not available. Approval actions are disabled.")
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Reusable card container with consistent styling
struct Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Extensions

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// MARK: - Preview Support

#Preview {
    let sampleRequest = ApprovalRequest(
        id: UUID(),
        tenantId: "sample-tenant-id",
        clientName: "Sample Client Corp",
        requestType: .passwordReset,
        description: "Password reset requested for john.doe@sampleclient.com",
        riskScore: 45,
        proposedActions: [
            ProposedAction(
                actionType: "password_reset",
                targetResource: "john.doe@sampleclient.com",
                currentState: ["status": "active", "lastLogin": "2025-09-01"],
                proposedState: ["status": "password_reset", "resetRequired": "true"],
                graphAPIEndpoint: "/users/john.doe@sampleclient.com/authentication/passwordMethods/28c10230-6103-485e-b985-444c60001490/resetPassword",
                graphAPIBody: nil,
                description: "Reset user password",
                impact: "User will be required to set new password on next login"
            )
        ],
        context: RequestContext(
            originalRequestContent: "Hi, John Smith from accounting forgot his password again. Can you reset it?",
            requestSource: "email",
            clientName: "Sample Client Corp",
            tenantId: "sample-tenant-id",
            requestorEmail: "manager@sampleclient.com",
            requestorName: "IT Manager",
            currentState: [:],
            additionalMetadata: [:],
            detectedAt: Date()
        ),
        expiresAt: Date().addingTimeInterval(300), // 5 minutes from now
        createdAt: Date().addingTimeInterval(-60), // 1 minute ago
        status: .pending
    )
    
    ApprovalCardView(
        request: sampleRequest,
        biometricService: BiometricService(),
        onApprove: { _ in },
        onReject: { _ in }
    )
    .padding()
}