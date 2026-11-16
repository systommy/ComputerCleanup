function Clear-SoftwareDistribution {
    <#
    .SYNOPSIS
    Removes selected cache files while restoring the original service state.
    .DESCRIPTION
    One confirmation covers stopping services, deleting cache contents and restoring
    previously running services. Abort on stop failure. Restore in finally. No rename,
    recursive directory deletion, robocopy, or changes to Download.old.
    .PARAMETER Force
    Suppress implicit confirmation. Explicit -Confirm and -WhatIf take precedence.
    .EXAMPLE
    Clear-SoftwareDistribution -WhatIf
    .OUTPUTS
    PSCustomObject with duration and observed disk-space delta.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param([switch] $Force)
    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) { $ConfirmPreference = 'None' }
    Assert-RunAsAdministrator
    $StopWatch = [Diagnostics.Stopwatch]::StartNew()
    $Before = Get-DiskSpace
    $Target = Join-Path $env:SystemRoot 'SoftwareDistribution\Download'
    if (-not (Test-SafeCleanupPath -LiteralPath $Target)) { throw 'Cache target is absent or has an unsafe ancestor.' }
    if ($PSCmdlet.ShouldProcess($Target, 'Stop related services, remove cache contents, restore previously running services')) {
        $Restore = @()
        try {
            $Restore = @(Stop-ServiceSet -ServiceNames @('wuauserv', 'bits') -Confirm:$false -ErrorAction Stop)
            Remove-StaleFiles -Paths @($Target) -AgeMode None -Confirm:$false -ErrorAction Stop
        }
        finally {
            if ($Restore.Count) { Start-ServiceSet -ServiceNames $Restore -Confirm:$false }
        }
    }
    New-CleanupReport -Name 'SoftwareDistribution' -StopWatch $StopWatch -DiskBefore $Before
}
