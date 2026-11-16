<#
    .SYNOPSIS
    Creates a cleanup result object from before/after disk space measurements.

    .DESCRIPTION
    Stops the provided stopwatch, captures current disk space, and returns a
    PSCustomObject with the cleanup section name, duration, and space metrics.
    All data is passed via parameters - no script-scope variable access.

    .PARAMETER Name
    The name of the cleanup section (e.g. 'BrowserCache', 'SystemFiles').

    .PARAMETER StopWatch
    A running System.Diagnostics.Stopwatch instance started before the cleanup operation.

    .PARAMETER DiskBefore
    The PSCustomObject returned by Get-DiskSpace before the cleanup operation.

    .EXAMPLE
    $Result = New-CleanupReport -Name 'BrowserCache' -StopWatch $StopWatch -DiskBefore $Before
    Returns a result object with Name, Duration, SpaceBefore, SpaceAfter, and SpaceCleaned.

    .OUTPUTS
    [PSCustomObject] with properties: Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function New-CleanupReport {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory report; no external state is changed.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch] $StopWatch,

        [Parameter(Mandatory)]
        [PSCustomObject] $DiskBefore
    )

    process {
        $StopWatch.Stop()
        $After = Get-DiskSpace

        [PSCustomObject]@{
            Name           = $Name
            IsPreview      = [bool]$WhatIfPreference
            Duration       = '{0:00.00} sec' -f $StopWatch.Elapsed.TotalSeconds
            SpaceBeforeGB  = $DiskBefore.FreeSpaceGB
            SpaceAfterGB   = $After.FreeSpaceGB
            SpaceCleanedGB = if ($WhatIfPreference) { 0 } else { [math]::Round($After.FreeSpaceGB - $DiskBefore.FreeSpaceGB, 2) }
        }
    }
}
