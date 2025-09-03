function Get-AIAgentAuthentication {
    [CmdletBinding()]
    param()
    
    try {
        # Use managed identity for Key Vault access
        $keyVaultName = $env:KEY_VAULT_NAME
        if (-not $keyVaultName) {
            # Fallback to local environment variables for development
            Write-Warning "KEY_VAULT_NAME not set, using local environment variables"
            
            $secrets = @{
                'OpenAI-API-Key' = $env:OPENAI_API_KEY
                'Claude-API-Key' = $env:CLAUDE_API_KEY
                'Graph-Client-Secret' = $env:GRAPH_CLIENT_SECRET
                'ServiceBus-Connection' = $env:SERVICE_BUS_CONNECTION
                'Storage-Connection' = $env:AZURE_STORAGE_CONNECTION_STRING
            }
            
            # Validate required secrets
            if (-not $secrets['OpenAI-API-Key']) {
                throw "OpenAI API key not found in environment variables"
            }
            
            return $secrets
        }
        
        # Production: Retrieve secrets from Key Vault
        $secrets = @{}
        $secretNames = @(
            'OpenAI-API-Key',
            'Claude-API-Key', 
            'Graph-Client-Secret',
            'ServiceBus-Connection',
            'Storage-Connection'
        )
        
        foreach ($secretName in $secretNames) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText -ErrorAction Stop
                $secrets[$secretName] = $secret
                Write-Information "Retrieved secret: $secretName"
            }
            catch {
                if ($secretName -eq 'OpenAI-API-Key') {
                    # OpenAI key is required
                    throw "Failed to retrieve required secret $secretName : $($_.Exception.Message)"
                }
                else {
                    # Other secrets are optional for now
                    Write-Warning "Failed to retrieve secret $secretName : $($_.Exception.Message)"
                    $secrets[$secretName] = $null
                }
            }
        }
        
        # Set environment variables for downstream functions
        $env:OPENAI_API_KEY = $secrets['OpenAI-API-Key']
        $env:CLAUDE_API_KEY = $secrets['Claude-API-Key']
        $env:GRAPH_CLIENT_SECRET = $secrets['Graph-Client-Secret']
        $env:SERVICE_BUS_CONNECTION = $secrets['ServiceBus-Connection']
        $env:AZURE_STORAGE_CONNECTION_STRING = $secrets['Storage-Connection']
        
        Write-Information "Authentication initialized successfully"
        return $secrets
    }
    catch {
        Write-Error "Authentication initialization failed: $($_.Exception.Message)"
        throw
    }
}