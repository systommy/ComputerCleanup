<#
    .SYNOPSIS
    Removes common system-wide temporary files and folders older than a specified number of days.

    .DESCRIPTION
    Cleans system temp directories including Windows\Temp, Logs\CBS,
    Downloaded Program Files, and Windows Error Reporting folders.
    Optionally clears the Windows Recycle Bin. Files are filtered by both
    CreationTime and LastWriteTime against the specified age threshold.
    Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Days
    Only remove files and folders older than this many days. Must be at least 1.

    .PARAMETER TempFiles
    Enable removal of system-wide temporary files.

    .PARAMETER RecycleBin
    Enable clearing of the Windows Recycle Bin.

    .PARAMETER Force
    Suppresses implicit confirmation. Explicit -Confirm and -WhatIf take precedence.

    .EXAMPLE
    Optimize-SystemFiles -Days 30 -TempFiles
    Removes system temp files older than 30 days.

    .EXAMPLE
    Optimize-SystemFiles -Days 7 -TempFiles -RecycleBin -Force
    Removes system temp files older than 7 days and empties the Recycle Bin without confirmation.

    .EXAMPLE
    Optimize-SystemFiles -Days 30 -TempFiles -WhatIf
    Shows what would be removed without actually deleting files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Optimize-SystemFiles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Retained existing command name for compatibility.')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Days,

        [Parameter()]
        [switch] $TempFiles,

        [Parameter()]
        [switch] $RecycleBin,

        [Parameter()]
        [switch] $Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Assert-RunAsAdministrator

        $StopWatch  = [System.Diagnostics.Stopwatch]::StartNew()
        $Before     = Get-DiskSpace
        $CutoffDate = (Get-Date).AddDays(-$Days)

        $Folders = @(
            (Join-Path -Path $env:SystemRoot -ChildPath 'Temp')
            (Join-Path -Path $env:SystemRoot -ChildPath 'Logs\CBS')
            (Join-Path -Path $env:SystemRoot -ChildPath 'Downloaded Program Files')
            (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER')
        )
    }

    process {
        if ($TempFiles) {
            Write-Verbose "Cleaning SYSTEM folders/files older than $Days days..."
            foreach ($Folder in $Folders) {
                if (Test-Path -Path $Folder) {
                    if ($PSCmdlet.ShouldProcess($Folder, "Remove files older than $Days days")) {
                        try {
                            Remove-StaleFiles -Paths @($Folder) -CutoffDate $CutoffDate -AgeMode 'CreationAndLastWrite' -Confirm:$false -ErrorAction Stop
                        }
                        catch {
                            Write-Error $_
                        }
                    }
                }
            }
            Write-Verbose 'Finished removing system temp files.'
        }

        if ($RecycleBin) {
            if ($PSCmdlet.ShouldProcess('Recycle Bin', 'Clear all items')) {
                try {
                    Write-Verbose 'Clearing Recycle Bin...'
                    Clear-RecycleBin -DriveLetter $env:SystemDrive.Substring(0, 1) -Force -ErrorAction Stop
                }
                catch {
                    Write-Error $_
                }
            }
        }
    }

    end {
        New-CleanupReport -Name 'SystemFiles' -StopWatch $StopWatch -DiskBefore $Before
    }
}
