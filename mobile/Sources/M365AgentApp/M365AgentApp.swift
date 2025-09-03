import SwiftUI
import SkipUI

@main
struct M365AgentApp: App {
    @StateObject private var approvalService = ApprovalService()
    @StateObject private var biometricService = BiometricService()
    @StateObject private var apiClient = APIClient()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(approvalService)
                .environmentObject(biometricService)
                .environmentObject(apiClient)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure push notifications
        configurePushNotifications()
        
        // Setup biometric authentication
        Task {
            await biometricService.checkBiometricAvailability()
        }
        
        // Initialize API client
        apiClient.configure()
        
        // Start checking for pending approvals
        Task {
            await approvalService.startPollingForApprovals()
        }
    }
    
    private func configurePushNotifications() {
        #if os(iOS)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        #endif
    }
}

struct ContentView: View {
    @EnvironmentObject private var approvalService: ApprovalService
    @EnvironmentObject private var biometricService: BiometricService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ApprovalListView()
                    .navigationTitle("AI TenantShield")
            }
            .tabItem {
                Label("Approvals", systemImage: "checkmark.shield.fill")
            }
            .tag(0)
            .badge(approvalService.pendingCount)
            
            NavigationStack {
                HistoryView()
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
    }
}

// Main approval list view
struct ApprovalListView: View {
    @EnvironmentObject private var approvalService: ApprovalService
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            if approvalService.pendingApprovals.isEmpty {
                ContentUnavailableView(
                    "No Pending Approvals",
                    systemImage: "checkmark.circle.fill",
                    description: Text("All M365 administrative requests have been processed")
                )
            } else {
                ForEach(approvalService.pendingApprovals) { approval in
                    ApprovalCardView(
                        request: approval,
                        onApprove: {
                            await approvalService.approve(approval)
                        },
                        onReject: {
                            await approvalService.reject(approval)
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await approvalService.refreshApprovals()
        }
        .overlay {
            if approvalService.isLoading && approvalService.pendingApprovals.isEmpty {
                ProgressView("Loading approvals...")
            }
        }
    }
}

// History view placeholder
struct HistoryView: View {
    var body: some View {
        List {
            ContentUnavailableView(
                "History",
                systemImage: "clock.arrow.circlepath",
                description: Text("Approval history will appear here")
            )
        }
    }
}

// Settings view placeholder
struct SettingsView: View {
    @EnvironmentObject private var biometricService: BiometricService
    @AppStorage("requireBiometric") private var requireBiometric = true
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    
    var body: some View {
        Form {
            Section("Security") {
                Toggle("Require Biometric Authentication", isOn: $requireBiometric)
                
                if biometricService.isAvailable {
                    HStack {
                        Text("Biometric Type")
                        Spacer()
                        Text(biometricService.biometryType.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Notifications") {
                Toggle("Auto-Refresh", isOn: $autoRefresh)
                
                if autoRefresh {
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                    }
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Environment")
                    Spacer()
                    Text("Production")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Approval Service
@MainActor
class ApprovalService: ObservableObject {
    @Published var pendingApprovals: [ApprovalRequest] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    var pendingCount: Int {
        pendingApprovals.count
    }
    
    private let apiClient = APIClient()
    private var refreshTimer: Timer?
    
    func startPollingForApprovals() async {
        await refreshApprovals()
        
        // Setup timer for auto-refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.refreshApprovals()
            }
        }
    }
    
    func refreshApprovals() async {
        isLoading = true
        error = nil
        
        do {
            pendingApprovals = try await apiClient.getPendingApprovals()
        } catch {
            self.error = error
            print("Failed to refresh approvals: \(error)")
        }
        
        isLoading = false
    }
    
    func approve(_ request: ApprovalRequest) async {
        do {
            let biometricService = BiometricService()
            let riskLevel = RiskLevel(score: request.riskScore)
            let biometricResult = try await biometricService.authenticateForApproval(riskLevel: riskLevel)
            
            let submission = ApprovalSubmission(
                requestId: request.id,
                approved: true,
                biometricConfirmation: biometricResult,
                timestamp: Date(),
                notes: nil
            )
            
            _ = try await apiClient.submitApproval(submission: submission)
            
            // Remove from pending list
            pendingApprovals.removeAll { $0.id == request.id }
        } catch {
            self.error = error
            print("Approval failed: \(error)")
        }
    }
    
    func reject(_ request: ApprovalRequest) async {
        do {
            let biometricService = BiometricService()
            let biometricResult = try await biometricService.authenticateForApproval(riskLevel: .low)
            
            let submission = ApprovalSubmission(
                requestId: request.id,
                approved: false,
                biometricConfirmation: biometricResult,
                timestamp: Date(),
                notes: "Rejected by user"
            )
            
            _ = try await apiClient.submitApproval(submission: submission)
            
            // Remove from pending list
            pendingApprovals.removeAll { $0.id == request.id }
        } catch {
            self.error = error
            print("Rejection failed: \(error)")
        }
    }
}

// API Client placeholder (basic implementation)
@MainActor
class APIClient: ObservableObject {
    private let baseURL: URL
    private var session: URLSession
    
    init() {
        // TODO: Configure with actual Azure Functions URL
        self.baseURL = URL(string: "https://ai-tenantshield.azurewebsites.net/api")!
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    func configure() {
        // Configure API client with authentication tokens
    }
    
    func getPendingApprovals() async throws -> [ApprovalRequest] {
        // TODO: Implement actual API call
        // For now, return empty array
        return []
    }
    
    func submitApproval(submission: ApprovalSubmission) async throws -> ApprovalResult {
        // TODO: Implement actual API call
        throw APIError.notImplemented
    }
}

enum APIError: LocalizedError {
    case notImplemented
    case unauthorized
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "API not yet implemented"
        case .unauthorized:
            return "Authentication required"
        case .networkError:
            return "Network connection error"
        }
    }
}