<#
    .SYNOPSIS
    Removes common temporary files and folders from user profiles older than a specified number of days.

    .DESCRIPTION
    Cleans per-user temp directories including Windows Error Reporting, IE Recovery,
    Terminal Server Client Cache, CrashDumps, and Local\Temp across all user profiles.
    Optionally removes large archive and installer files from users' Downloads folders.
    Files are filtered by both CreationTime and LastAccessTime against the specified
    age threshold. Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Days
    Only remove files and folders older than this many days. Must be at least 1.

    .PARAMETER TempFiles
    Enable removal of common temporary files from user profiles.

    .PARAMETER Downloads
    Enable cleanup of users' Downloads folders (requires -ArchiveFiles or -GenericFiles).

    .PARAMETER ArchiveFiles
    Remove archive files (.zip, .rar, .7z, .iso by default) larger than ArchiveSize from Downloads.

    .PARAMETER ArchiveTypes
    File extensions to consider as archive files. Defaults to zip, rar, 7z, iso.

    .PARAMETER ArchiveSize
    Minimum file size for archive removal. Defaults to 500MB.

    .PARAMETER GenericFiles
    Remove installer/executable files (.msi, .exe by default) larger than GenericSize from Downloads.

    .PARAMETER GenericTypes
    File extensions to consider as generic installer files. Defaults to msi, exe.

    .PARAMETER GenericSize
    Minimum file size for generic file removal. Defaults to 15MB.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Optimize-UserProfiles -Days 30 -TempFiles
    Removes user temp files older than 30 days.

    .EXAMPLE
    Optimize-UserProfiles -Days 60 -TempFiles -Downloads -ArchiveFiles -Force
    Removes temp files and large archives from Downloads without confirmation.

    .EXAMPLE
    Optimize-UserProfiles -Days 30 -TempFiles -WhatIf
    Shows what would be removed without actually deleting files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Optimize-UserProfiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Days,

        [Parameter()]
        [switch] $TempFiles,

        [Parameter()]
        [switch] $Downloads,

        [Parameter()]
        [switch] $ArchiveFiles,

        [Parameter()]
        [string[]] $ArchiveTypes = @('zip', 'rar', '7z', 'iso'),

        [Parameter()]
        [string] $ArchiveSize = '500MB',

        [Parameter()]
        [switch] $GenericFiles,

        [Parameter()]
        [string[]] $GenericTypes = @('msi', 'exe'),

        [Parameter()]
        [string] $GenericSize = '15MB',

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
        $Users      = Get-UserFolders
        $CutoffDate = (Get-Date).AddDays(-$Days)

        $CommonParams = @{
            Recurse       = $true
            Force         = $true
            ErrorAction   = 'SilentlyContinue'
            WarningAction = 'SilentlyContinue'
        }
    }

    process {
        foreach ($UserName in $Users) {
            if ($TempFiles) {
                $TempFolders = @(
                    'AppData\Local\Microsoft\Windows\WER',
                    'AppData\Local\Microsoft\Internet Explorer\Recovery',
                    'AppData\Local\Microsoft\Terminal Server Client\Cache',
                    'AppData\Local\CrashDumps',
                    'AppData\Local\Temp'
                )

                foreach ($FolderName in $TempFolders) {
                    $FolderToClean = Join-Path -Path "$env:SYSTEMDRIVE\Users\$UserName" -ChildPath $FolderName
                    if (Test-Path -Path $FolderToClean) {
                        if ($PSCmdlet.ShouldProcess($FolderToClean, "Remove files older than $Days days")) {
                            try {
                                Remove-StaleFiles -Paths @($FolderToClean) -CutoffDate $CutoffDate -AgeMode 'CreationAndLastAccess'
                            }
                            catch {
                                Write-Error $_
                            }
                        }
                    }
                }
                Write-Verbose "Finished removing temp files for $UserName."
            }

            if ($Downloads) {
                $DownloadsPath = Join-Path -Path "$env:SYSTEMDRIVE\Users\$UserName" -ChildPath 'Downloads'
                if (Test-Path -Path $DownloadsPath) {
                    if ($ArchiveFiles) {
                        foreach ($Ext in $ArchiveTypes) {
                            if ($PSCmdlet.ShouldProcess("$DownloadsPath\*.$Ext (> $ArchiveSize, > $Days days)", 'Remove archive files')) {
                                try {
                                    Get-ChildItem -Path "$DownloadsPath\*.$Ext" @CommonParams |
                                        Where-Object {
                                            $_.CreationTime -lt $CutoffDate -and
                                            $_.LastAccessTime -lt $CutoffDate -and
                                            $_.Length -gt $ArchiveSize
                                        } |
                                        Remove-Item @CommonParams
                                }
                                catch {
                                    Write-Error $_
                                }
                            }
                        }
                    }

                    if ($GenericFiles) {
                        foreach ($Ext in $GenericTypes) {
                            if ($PSCmdlet.ShouldProcess("$DownloadsPath\*.$Ext (> $GenericSize, > $Days days)", 'Remove installer files')) {
                                try {
                                    Get-ChildItem -Path "$DownloadsPath\*.$Ext" @CommonParams |
                                        Where-Object {
                                            $_.CreationTime -lt $CutoffDate -and
                                            $_.LastAccessTime -lt $CutoffDate -and
                                            $_.Length -gt $GenericSize
                                        } |
                                        Remove-Item @CommonParams
                                }
                                catch {
                                    Write-Error $_
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    end {
        New-CleanupReport -Name 'UserProfiles' -StopWatch $StopWatch -DiskBefore $Before
    }
}
