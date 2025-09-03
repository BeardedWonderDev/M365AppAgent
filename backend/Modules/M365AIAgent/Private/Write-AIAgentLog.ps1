function Write-AIAgentLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information',
        
        [Parameter()]
        [hashtable]$Properties = @{},
        
        [Parameter()]
        [string]$FunctionName,
        
        [Parameter()]
        [string]$RequestId,
        
        [Parameter()]
        [string]$TenantId
    )
    
    # Structure log data for Application Insights
    $logData = @{
        message = $Message
        level = $Level
        functionName = $FunctionName
        requestId = $RequestId
        tenantId = $TenantId
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        properties = $Properties
    }
    
    # Use appropriate PowerShell logging cmdlets
    $logJson = $logData | ConvertTo-Json -Compress
    
    switch ($Level) {
        'Information' { 
            Write-Information $logJson -InformationAction Continue 
        }
        'Warning' { 
            Write-Warning $logJson 
        }
        'Error' { 
            Write-Error $logJson 
        }
        'Debug' { 
            Write-Debug $logJson 
        }
    }
    
    # Also send to Azure Table Storage for audit trail (if available)
    try {
        if ($env:AZURE_STORAGE_CONNECTION_STRING) {
            $storageContext = New-AzStorageContext -ConnectionString $env:AZURE_STORAGE_CONNECTION_STRING -ErrorAction SilentlyContinue
            
            if ($storageContext) {
                $logTable = Get-AzStorageTable -Name 'AIAgentLogs' -Context $storageContext -ErrorAction SilentlyContinue
                
                if ($logTable) {
                    $logEntity = @{
                        PartitionKey = (Get-Date).ToString('yyyy-MM-dd')
                        RowKey = "$RequestId-$((Get-Date).Ticks)"
                        Message = $Message
                        Level = $Level
                        FunctionName = $FunctionName
                        TenantId = $TenantId
                        Properties = ($Properties | ConvertTo-Json -Compress)
                    }
                    
                    Add-AzTableRow -Table $logTable.CloudTable -PartitionKey $logEntity.PartitionKey -RowKey $logEntity.RowKey -Property $logEntity -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch {
        # Don't fail the main function if logging to table fails
        Write-Warning "Failed to write to Azure Table Storage: $($_.Exception.Message)"
    }
}