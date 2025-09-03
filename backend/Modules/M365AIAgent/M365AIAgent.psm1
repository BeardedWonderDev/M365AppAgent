# M365AIAgent Module
# Main module file that loads all functions and classes

# Import classes first
. $PSScriptRoot\Classes\AIModels.ps1

# Import Private functions
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $Private) {
    try {
        . $import.FullName
        Write-Verbose "Imported private function: $($import.Name)"
    }
    catch {
        Write-Error "Failed to import private function $($import.Name): $_"
    }
}

# Import Public functions
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $Public) {
    try {
        . $import.FullName
        Write-Verbose "Imported public function: $($import.Name)"
    }
    catch {
        Write-Error "Failed to import public function $($import.Name): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

Write-Information "M365AIAgent module loaded successfully"