#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test runner for M365AIAgent PowerShell tests
.DESCRIPTION
    Comprehensive test runner that executes all Pester tests for the M365AIAgent module
    Supports CI/CD integration, coverage reporting, and performance benchmarks
.PARAMETER TestType
    Type of tests to run: All, Unit, Integration, Performance
.PARAMETER GenerateCoverage
    Generate code coverage report
.PARAMETER OutputFormat
    Output format for test results: NUnitXml, JUnitXml, Console
.PARAMETER Verbose
    Enable verbose test output
.EXAMPLE
    .\Run-Tests.ps1 -TestType All -GenerateCoverage -OutputFormat JUnitXml
.NOTES
    Author: AI TenantShield Development Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("All", "Unit", "Integration", "Performance")]
    [string]$TestType = "All",
    
    [Parameter()]
    [switch]$GenerateCoverage,
    
    [Parameter()]
    [ValidateSet("Console", "NUnitXml", "JUnitXml")]
    [string]$OutputFormat = "Console",
    
    [Parameter()]
    [switch]$Verbose
)

# Initialize script variables
$ErrorActionPreference = 'Stop'
$TestsPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path (Split-Path -Parent $TestsPath) 'Modules' 'M365AIAgent'
$OutputPath = Join-Path $TestsPath 'TestResults'

# Import required modules
try {
    Import-Module Pester -MinimumVersion 5.0.0 -Force
    Write-Host "✓ Pester module imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import Pester module. Please install Pester 5.x: Install-Module -Name Pester -Force"
    exit 1
}

# Import test configuration
$TestConfigPath = Join-Path $TestsPath 'TestConfig.ps1'
if (Test-Path $TestConfigPath) {
    . $TestConfigPath
    Initialize-TestEnvironment -SetupMockData
    Write-Host "✓ Test configuration loaded" -ForegroundColor Green
}
else {
    Write-Warning "Test configuration file not found: $TestConfigPath"
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "✓ Created test output directory: $OutputPath" -ForegroundColor Yellow
}

# Configure Pester settings
$PesterConfiguration = [PesterConfiguration]@{
    Run = @{
        Path = $TestsPath
        PassThru = $true
        Throw = $false
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = $OutputFormat
        OutputPath = Join-Path $OutputPath "TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($OutputFormat.ToLower())"
    }
    Output = @{
        Verbosity = if ($Verbose) { 'Detailed' } else { 'Normal' }
        StackTraceVerbosity = 'Filtered'
        CIFormat = 'Auto'
    }
    Filter = @{
        Tag = @()
        ExcludeTag = @()
    }
}

# Configure code coverage if requested
if ($GenerateCoverage) {
    $PesterConfiguration.CodeCoverage = @{
        Enabled = $true
        Path = @(
            Join-Path $ModulePath '*.ps1'
            Join-Path $ModulePath 'Public' '*.ps1'
            Join-Path $ModulePath 'Private' '*.ps1'
            Join-Path $ModulePath 'Classes' '*.ps1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = Join-Path $OutputPath "CodeCoverage-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }
    Write-Host "✓ Code coverage enabled" -ForegroundColor Cyan
}

# Apply test type filters
switch ($TestType) {
    "Unit" {
        $PesterConfiguration.Filter.Tag = @('Unit')
        Write-Host "✓ Running Unit tests only" -ForegroundColor Yellow
    }
    "Integration" {
        $PesterConfiguration.Filter.Tag = @('Integration')
        Write-Host "✓ Running Integration tests only" -ForegroundColor Yellow
    }
    "Performance" {
        $PesterConfiguration.Filter.Tag = @('Performance')
        Write-Host "✓ Running Performance tests only" -ForegroundColor Yellow
    }
    "All" {
        Write-Host "✓ Running all tests" -ForegroundColor Cyan
    }
}

# Display test execution banner
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    M365 AI AGENT - POWERSHELL TEST EXECUTION" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Type:      $TestType" -ForegroundColor White
Write-Host "Coverage:       $(if ($GenerateCoverage) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
Write-Host "Output Format:  $OutputFormat" -ForegroundColor White
Write-Host "Module Path:    $ModulePath" -ForegroundColor Gray
Write-Host "Tests Path:     $TestsPath" -ForegroundColor Gray
Write-Host "Output Path:    $OutputPath" -ForegroundColor Gray
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Execute tests
$TestStartTime = Get-Date
Write-Host "🚀 Starting test execution at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green

try {
    $TestResults = Invoke-Pester -Configuration $PesterConfiguration
    
    $TestEndTime = Get-Date
    $TestDuration = $TestEndTime - $TestStartTime
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "    TEST EXECUTION SUMMARY" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Duration:       $($TestDuration.ToString('mm\:ss\.fff'))" -ForegroundColor White
    Write-Host "Total Tests:    $($TestResults.TotalCount)" -ForegroundColor White
    Write-Host "Passed:         $($TestResults.PassedCount)" -ForegroundColor Green
    Write-Host "Failed:         $($TestResults.FailedCount)" -ForegroundColor $(if ($TestResults.FailedCount -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Skipped:        $($TestResults.SkippedCount)" -ForegroundColor Yellow
    Write-Host "Inconclusive:   $($TestResults.InconclusiveCount)" -ForegroundColor Yellow
    
    # Display code coverage if enabled
    if ($GenerateCoverage -and $TestResults.CodeCoverage) {
        $CoveragePercent = [Math]::Round(($TestResults.CodeCoverage.NumberOfCommandsExecuted / $TestResults.CodeCoverage.NumberOfCommandsAnalyzed) * 100, 2)
        $CoverageColor = if ($CoveragePercent -ge 80) { 'Green' } elseif ($CoveragePercent -ge 60) { 'Yellow' } else { 'Red' }
        
        Write-Host "Coverage:       $CoveragePercent% ($($TestResults.CodeCoverage.NumberOfCommandsExecuted)/$($TestResults.CodeCoverage.NumberOfCommandsAnalyzed) commands)" -ForegroundColor $CoverageColor
        
        if ($TestResults.CodeCoverage.MissedCommands.Count -gt 0) {
            Write-Host ""
            Write-Host "Missed Commands:" -ForegroundColor Yellow
            $TestResults.CodeCoverage.MissedCommands | 
                Select-Object File, Line, Command -First 10 |
                ForEach-Object { 
                    Write-Host "  $($_.File):$($_.Line) - $($_.Command)" -ForegroundColor Gray
                }
            
            if ($TestResults.CodeCoverage.MissedCommands.Count -gt 10) {
                Write-Host "  ... and $($TestResults.CodeCoverage.MissedCommands.Count - 10) more" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Display test failures if any
    if ($TestResults.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "❌ FAILED TESTS:" -ForegroundColor Red
        $TestResults.Tests | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object {
            Write-Host "  • $($_.Name)" -ForegroundColor Red
            if ($_.ErrorRecord) {
                Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor Gray
            }
        }
    }
    
    # Performance summary
    if ($TestType -eq "All" -or $TestType -eq "Performance") {
        $SlowTests = $TestResults.Tests | 
            Where-Object { $_.Duration -gt [TimeSpan]::FromSeconds(1) } |
            Sort-Object Duration -Descending |
            Select-Object -First 5
        
        if ($SlowTests) {
            Write-Host ""
            Write-Host "🐌 SLOWEST TESTS:" -ForegroundColor Yellow
            $SlowTests | ForEach-Object {
                Write-Host "  • $($_.Name) - $($_.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Yellow
            }
        }
    }
    
    # Export results
    if ($OutputFormat -ne "Console") {
        Write-Host ""
        Write-Host "📄 Test results exported to: $($PesterConfiguration.TestResult.OutputPath)" -ForegroundColor Cyan
    }
    
    if ($GenerateCoverage) {
        Write-Host "📊 Coverage report exported to: $($PesterConfiguration.CodeCoverage.OutputPath)" -ForegroundColor Cyan
    }
    
    # Determine exit code
    $ExitCode = if ($TestResults.FailedCount -eq 0) { 0 } else { 1 }
    
    if ($ExitCode -eq 0) {
        Write-Host ""
        Write-Host "✅ All tests passed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "❌ Some tests failed. Check the results above." -ForegroundColor Red
    }
    
    return $ExitCode
}
catch {
    Write-Host ""
    Write-Host "💥 Test execution failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    return 1
}
finally {
    # Cleanup test environment
    if (Get-Command Cleanup-TestEnvironment -ErrorAction SilentlyContinue) {
        Cleanup-TestEnvironment
        Write-Host "🧹 Test environment cleaned up" -ForegroundColor Gray
    }
}