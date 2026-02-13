<#
    .SYNOPSIS
    Clears user font cache files.

    .DESCRIPTION
    Stops the Windows Font Cache service, removes font cache .dat files from
    the LocalService profile, then restarts the service. Supports -WhatIf,
    -Confirm, and -Force.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Clear-FontCache
    Clears font cache files (prompts for confirmation due to service restart).

    .EXAMPLE
    Clear-FontCache -Force
    Clears font cache files without confirmation.

    .EXAMPLE
    Clear-FontCache -WhatIf
    Shows what would happen without actually stopping services or removing files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Clear-FontCache {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch] $Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Assert-RunAsAdministrator

        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Before    = Get-DiskSpace

        $Folder = Join-Path -Path $env:SystemRoot -ChildPath 'ServiceProfiles\LocalService\AppData\Local'
        $Filter = 'FontCache-S-*.dat'
        $ServicesToRestore = @()
    }

    process {
        if ($PSCmdlet.ShouldProcess('FontCache service', 'Stop service')) {
            try {
                $ServicesToRestore = Stop-ServiceSet -ServiceNames @('fontcache')
            }
            catch {
                Write-Warning $_
            }
        }

        if (Test-Path -Path $Folder) {
            if ($PSCmdlet.ShouldProcess($Folder, 'Remove font cache files')) {
                try {
                    Write-Verbose "Cleaning directory: $Folder"
                    Remove-StaleFiles -Paths @($Folder) -AgeMode 'None' -FileNamePattern $Filter
                    Write-Verbose 'Finished removing font cache files.'
                }
                catch {
                    Write-Warning $_
                }
            }
        }

        if ($ServicesToRestore.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess('FontCache service', 'Start service')) {
                try {
                    Start-ServiceSet -ServiceNames $ServicesToRestore
                }
                catch {
                    Write-Warning $_
                }
            }
        }
    }

    end {
        New-CleanupReport -Name 'FontCache' -StopWatch $StopWatch -DiskBefore $Before
    }
}
