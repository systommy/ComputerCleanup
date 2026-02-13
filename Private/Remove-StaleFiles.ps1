<#
    .SYNOPSIS
    Removes files and directories using .NET I/O APIs.

    .DESCRIPTION
    Enumerates filesystem entries with reparse-point protection, applies optional
    age filtering, and deletes matched files/directories while suppressing common
    IO and access errors. Uses a PS 7+ EnumerationOptions path and a PS 5.1
    DirectoryInfo path for dual compatibility.

    .PARAMETER Paths
    One or more filesystem paths (files, directories, or wildcard paths).

    .PARAMETER CutoffDate
    Optional datetime threshold used with age-based modes.

    .PARAMETER AgeMode
    None, CreationAndLastAccess, or CreationAndLastWrite.

    .PARAMETER FileNamePattern
    Optional file name match pattern. Defaults to '*'.

    .OUTPUTS
    None
#>
function Remove-StaleFiles {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string[]] $Paths,

        [Parameter()]
        [Nullable[datetime]] $CutoffDate,

        [Parameter()]
        [ValidateSet('None', 'CreationAndLastAccess', 'CreationAndLastWrite')]
        [string] $AgeMode = 'None',

        [Parameter()]
        [string] $FileNamePattern = '*'
    )

    begin {
        if ($AgeMode -ne 'None' -and -not $CutoffDate) {
            throw 'CutoffDate is required when AgeMode is not None.'
        }

        $CutoffUtc = if ($CutoffDate) {
            $CutoffDate.Value.ToUniversalTime()
        }
        else {
            [datetime]::MinValue
        }

        function Test-AgeMatch {
            param(
                [Parameter(Mandatory)]
                [System.IO.FileSystemInfo] $Item,

                [Parameter(Mandatory)]
                [datetime] $ThresholdUtc,

                [Parameter(Mandatory)]
                [string] $Mode
            )

            if ($Mode -eq 'None') {
                return $true
            }

            if ($Mode -eq 'CreationAndLastAccess') {
                return ($Item.CreationTimeUtc -lt $ThresholdUtc -and $Item.LastAccessTimeUtc -lt $ThresholdUtc)
            }

            return ($Item.CreationTimeUtc -lt $ThresholdUtc -and $Item.LastWriteTimeUtc -lt $ThresholdUtc)
        }
    }

    process {
        foreach ($InputPath in $Paths) {
            if ([string]::IsNullOrWhiteSpace($InputPath)) {
                continue
            }

            $Targets = @(Get-Item -Path $InputPath -Force -ErrorAction SilentlyContinue)
            if ($Targets.Count -eq 0) {
                continue
            }

            foreach ($Target in $Targets) {
                if ($Target -is [System.IO.FileInfo]) {
                    if ($FileNamePattern -ne '*' -and $Target.Name -notlike $FileNamePattern) {
                        continue
                    }

                    if (-not (Test-AgeMatch -Item $Target -ThresholdUtc $CutoffUtc -Mode $AgeMode)) {
                        continue
                    }

                    try {
                        [System.IO.File]::Delete($Target.FullName)
                        Write-Verbose "Deleted file: $($Target.FullName)"
                    }
                    catch {
                        Write-Verbose "Failed to delete file '$($Target.FullName)': $($_.Exception.Message)"
                    }

                    continue
                }

                if (($Target.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    Write-Verbose "Skipping reparse point root: $($Target.FullName)"
                    continue
                }

                $Entries = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]

                try {
                    $DirectoryInfo = [System.IO.DirectoryInfo]::new($Target.FullName)

                    if ($PSVersionTable.PSVersion.Major -ge 7) {
                        $EnumerationOptions = [System.IO.EnumerationOptions]::new()
                        $EnumerationOptions.RecurseSubdirectories = $true
                        $EnumerationOptions.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint
                        $EnumerationOptions.IgnoreInaccessible = $true

                        foreach ($Entry in $DirectoryInfo.EnumerateFileSystemInfos('*', $EnumerationOptions)) {
                            $Entries.Add($Entry)
                        }
                    }
                    else {
                        foreach ($Entry in $DirectoryInfo.EnumerateFileSystemInfos('*', [System.IO.SearchOption]::AllDirectories)) {
                            if (($Entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                                continue
                            }

                            $Entries.Add($Entry)
                        }
                    }
                }
                catch {
                    Write-Verbose "Enumeration failed for '$($Target.FullName)': $($_.Exception.Message)"
                    continue
                }

                $FilesToDelete = @(
                    $Entries | Where-Object {
                        $_ -is [System.IO.FileInfo] -and
                        ($FileNamePattern -eq '*' -or $_.Name -like $FileNamePattern) -and
                        (Test-AgeMatch -Item $_ -ThresholdUtc $CutoffUtc -Mode $AgeMode)
                    }
                )

                foreach ($File in $FilesToDelete) {
                    try {
                        [System.IO.File]::Delete($File.FullName)
                        Write-Verbose "Deleted file: $($File.FullName)"
                    }
                    catch {
                        Write-Verbose "Failed to delete file '$($File.FullName)': $($_.Exception.Message)"
                    }
                }

                if ($FileNamePattern -eq '*') {
                    $DirectoriesToDelete = @(
                        $Entries | Where-Object {
                            $_ -is [System.IO.DirectoryInfo] -and
                            (Test-AgeMatch -Item $_ -ThresholdUtc $CutoffUtc -Mode $AgeMode)
                        } | Sort-Object { $_.FullName.Length } -Descending
                    )

                    foreach ($Directory in $DirectoriesToDelete) {
                        try {
                            [System.IO.Directory]::Delete($Directory.FullName, $true)
                            Write-Verbose "Deleted directory: $($Directory.FullName)"
                        }
                        catch {
                            Write-Verbose "Failed to delete directory '$($Directory.FullName)': $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
    }
}



