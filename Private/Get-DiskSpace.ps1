<#
    .SYNOPSIS
    Gets available disk space for a specified drive.

    .DESCRIPTION
    Returns a PSCustomObject with drive letter, total size, and free space in GB.
    Used internally for before/after disk space comparison in cleanup functions.

    .PARAMETER DriveLetter
    The drive letter to check. Defaults to 'C'.

    .EXAMPLE
    Get-DiskSpace
    Returns disk space information for the C: drive.

    .EXAMPLE
    Get-DiskSpace -DriveLetter 'D'
    Returns disk space information for the D: drive.

    .OUTPUTS
    [PSCustomObject] with properties: DriveLetter, TotalSizeGB, FreeSpaceGB

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Get-DiskSpace {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidatePattern('^[A-Za-z]$')]
        [string] $DriveLetter = 'C'
    )

    process {
        $Disk = [System.IO.DriveInfo]::new("$DriveLetter`:")

        [PSCustomObject]@{
            DriveLetter = $DriveLetter.ToUpperInvariant()
            TotalSizeGB = [math]::Round($Disk.TotalSize / 1GB, 2)
            FreeSpaceGB = [math]::Round($Disk.AvailableFreeSpace / 1GB, 2)
        }
    }
}
