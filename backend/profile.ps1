# Azure Functions PowerShell profile.ps1
# This file is executed when the Function App starts

Write-Information "AI TenantShield - PowerShell Version: $($PSVersionTable.PSVersion)"

# Import required modules with error handling
@('Az.Accounts', 'Az.KeyVault', 'Az.Storage', 'Az.ServiceBus', 'Microsoft.Graph.Authentication', 'M365AIAgent') | ForEach-Object {
    try {
        $Module = $_
        
        # Check if module is already loaded
        if (Get-Module -Name $Module -ErrorAction SilentlyContinue) {
            Write-Information "Module already loaded: $Module"
        }
        else {
            Import-Module -Name $Module -ErrorAction Stop -Force
            Write-Information "Successfully imported module: $Module"
        }
    }
    catch {
        Write-Error "Failed to import module - $Module : $($_.Exception.Message)"
        # Don't throw here, log and continue to allow partial functionality
    }
}

# Disable Azure context autosave for Functions (CRITICAL)
try {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Write-Information "Disabled Az context autosave"
}
catch {
    Write-Warning "Could not disable Az context autosave: $($_.Exception.Message)"
}

# Initialize authentication if not from profile
try {
    if (!$env:SetFromProfile) {
        Write-Information "Initializing authentication from Key Vault"
        
        # Set flag to prevent re-initialization
        $env:SetFromProfile = $true
        
        # Get authentication secrets
        $Auth = Get-AIAgentAuthentication
        
        Write-Information "Authentication initialized successfully"
    }
}
catch {
    Write-Error "Could not retrieve authentication: $($_.Exception.Message)"
    # Don't throw - allow functions to handle missing auth
}

# Set working directory
Set-Location -Path $PSScriptRoot

# Version tracking for cache invalidation
try {
    $VersionFile = Join-Path $PSScriptRoot "version.txt"
    if (Test-Path $VersionFile) {
        $CurrentVersion = (Get-Content $VersionFile -ErrorAction SilentlyContinue)?.Trim()
        if ($CurrentVersion) {
            Write-Information "Function App Version: $CurrentVersion"
            $env:FUNCTION_APP_VERSION = $CurrentVersion
        }
    }
    else {
        $env:FUNCTION_APP_VERSION = "1.0.0"
        Write-Information "Function App Version: 1.0.0 (default)"
    }
}
catch {
    Write-Warning "Could not determine Function App version: $($_.Exception.Message)"
}

# Configure Application Insights if available
if ($env:APPINSIGHTS_INSTRUMENTATIONKEY -or $env:APPLICATIONINSIGHTS_CONNECTION_STRING) {
    Write-Information "Application Insights configured"
}
else {
    Write-Warning "Application Insights not configured - telemetry will be limited"
}

# Set default error action preference
$ErrorActionPreference = 'Stop'

# Configure progress preference for better performance
$ProgressPreference = 'SilentlyContinue'

Write-Information "Profile initialization complete"