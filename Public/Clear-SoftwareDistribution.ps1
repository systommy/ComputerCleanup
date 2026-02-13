<#
    .SYNOPSIS
    Cleans the Windows Update SoftwareDistribution Downloads folder.

    .DESCRIPTION
    Stops the Windows Update and BITS services, renames and removes the
    SoftwareDistribution\Download folder, then restarts the services.
    Falls back to robocopy for long file paths. Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Clear-SoftwareDistribution
    Cleans the SoftwareDistribution folder (prompts for confirmation).

    .EXAMPLE
    Clear-SoftwareDistribution -Force
    Cleans without confirmation.

    .EXAMPLE
    Clear-SoftwareDistribution -WhatIf
    Shows what would happen without stopping services or removing files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Clear-SoftwareDistribution {
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

        $StopWatch    = [System.Diagnostics.Stopwatch]::StartNew()
        $Before       = Get-DiskSpace
        $DownloadPath = Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download'
        $OldPath      = Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download.old'

        $ServicesToManage  = @('wuauserv', 'bits')
        $ServicesToRestore = @()
    }

    process {
        if ($PSCmdlet.ShouldProcess('wuauserv, bits', 'Stop services')) {
            try {
                Write-Verbose 'Stopping Windows Update & Background Intelligent Transfer services...'
                $ServicesToRestore = Stop-ServiceSet -ServiceNames $ServicesToManage
            }
            catch {
                Write-Warning $_
            }
        }

        if ($PSCmdlet.ShouldProcess($DownloadPath, 'Rename to Download.old')) {
            try {
                if (Test-Path -Path $DownloadPath) {
                    Write-Verbose 'Renaming "SoftwareDistribution\Download" folder to "Download.old"...'
                    Rename-Item -Path $DownloadPath -NewName 'Download.old' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                }
            }
            catch {
                Write-Error $_
            }
        }

        if ($PSCmdlet.ShouldProcess($OldPath, 'Remove folder')) {
            try {
                if (Test-Path -Path $OldPath) {
                    Write-Verbose 'Cleaning SoftwareDistribution\Download.old folder...'
                    [System.IO.Directory]::Delete($OldPath, $true)
                }
                Write-Verbose 'Finished cleaning SoftwareDistribution folder.'
            }
            catch {
                try {
                    Write-Warning 'Some file paths could not be removed directly. Trying robocopy to remove files/folders...'
                    $EmptyDir = Join-Path -Path $env:TEMP -ChildPath 'EmptyDir_SoftDist'
                    New-Item -ItemType Directory -Path $EmptyDir -ErrorAction SilentlyContinue | Out-Null
                    robocopy /MIR $EmptyDir $OldPath /njh /njs /ndl /nc /ns /np /nfl 2>&1 | Out-Null
                    Remove-Item $OldPath -Force -ErrorAction SilentlyContinue
                    Remove-Item $EmptyDir -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Error $_
                }
            }
        }

        if ($ServicesToRestore.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess('wuauserv, bits', 'Start services')) {
                try {
                    Write-Verbose 'Starting previously running Windows Update & Background Intelligent Transfer services...'
                    Start-ServiceSet -ServiceNames $ServicesToRestore
                }
                catch {
                    Write-Warning $_
                }
            }
        }
    }

    end {
        New-CleanupReport -Name 'SoftwareDistribution' -StopWatch $StopWatch -DiskBefore $Before
    }
}
