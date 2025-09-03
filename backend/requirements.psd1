@{
    # Azure modules (MANDATORY)
    'Az.Accounts' = '2.*'
    'Az.KeyVault' = '4.*'
    'Az.Storage' = '5.*'
    'Az.ServiceBus' = '1.*'
    
    # Microsoft Graph (MANDATORY for M365 operations)
    'Microsoft.Graph.Authentication' = '2.*'
    'Microsoft.Graph.Users' = '2.*'
    'Microsoft.Graph.Groups' = '2.*'
    'Microsoft.Graph.Identity.DirectoryManagement' = '2.*'
    
    # Table Storage for audit logs
    'AzTable' = '2.*'
    
    # JSON and data processing
    'PowerShellGet' = '2.*'
    
    # Testing framework (for local development)
    'Pester' = '5.*'
    
    # Script analysis
    'PSScriptAnalyzer' = '1.*'
}