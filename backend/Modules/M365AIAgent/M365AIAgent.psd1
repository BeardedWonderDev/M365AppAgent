@{
    # Module manifest for M365AIAgent module
    ModuleVersion = '1.0.0'
    GUID = 'a7b9c8d3-4e5f-6a7b-8c9d-0e1f2a3b4c5d'
    Author = 'CoManaged IT Solutions'
    CompanyName = 'CoManaged IT Solutions'
    Copyright = '(c) 2025 CoManaged IT Solutions. All rights reserved.'
    Description = 'M365 AI Agent module for automated tenant management with AI classification and mobile approval workflows'
    PowerShellVersion = '7.4'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0'; GUID = 'c6142069-51e1-4709-a9e4-e9abe1c8e54f'}
        @{ModuleName = 'Az.KeyVault'; ModuleVersion = '4.0.0'; GUID = '0c56db03-c0e2-48e1-b4f2-0d2e8e9b4b9e'}
        @{ModuleName = 'Az.Storage'; ModuleVersion = '5.0.0'; GUID = 'c33c9b94-eaf0-4ba9-b855-f5cce0e8b4a3'}
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '1.0.0'}
        @{ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '1.0.0'}
        @{ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '1.0.0'}
        @{ModuleName = 'AzTable'; ModuleVersion = '2.0.0'}
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-AIClassification'
        'Get-AIAgentAuthentication'
        'New-ApprovalRequest'
        'Get-ApprovalRequest'
        'Submit-ApprovalDecision'
        'Invoke-CIPPAction'
        'Write-AIAgentLog'
        'Get-ExpiredApprovalRequests'
        'Remove-ApprovalRequest'
        'Save-ClassificationResult'
        'Send-ApprovalNotification'
        'Invoke-AutoExecution'
        'Test-EmailWebhookSignature'
        'Get-CippException'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # DSC resources to export from this module
    DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    ModuleList = @()
    
    # List of all files packaged with this module
    FileList = @(
        'M365AIAgent.psd1'
        'M365AIAgent.psm1'
        'Classes/AIModels.ps1'
        'Private/Invoke-AIClassification.ps1'
        'Private/Get-AIAgentAuthentication.ps1'
        'Private/Write-AIAgentLog.ps1'
        'Private/Get-CippException.ps1'
        'Public/New-ApprovalRequest.ps1'
        'Public/Get-ApprovalRequest.ps1'
        'Public/Submit-ApprovalDecision.ps1'
        'Public/Invoke-CIPPAction.ps1'
        'Public/Send-ApprovalNotification.ps1'
        'Public/Invoke-AutoExecution.ps1'
    )
    
    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('M365', 'AI', 'Automation', 'MSP', 'TenantManagement', 'Azure')
            
            # A URL to the license for this module
            LicenseUri = ''
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/CoManaged/M365AIAgent'
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of M365 AI Agent module with AI classification and mobile approval workflows'
            
            # Prerelease string of this module
            Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            ExternalModuleDependencies = @()
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = ''
    
    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''
    
    # Root module/script file
    RootModule = 'M365AIAgent.psm1'
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @('Classes/AIModels.ps1')
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule
    NestedModules = @()
    
    # Assembly files (.dll) to load when importing this module
    RequiredAssemblies = @()
}