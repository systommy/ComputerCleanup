<#
    .SYNOPSIS
    Gets all user profile folder names, excluding system and admin accounts.

    .DESCRIPTION
    Enumerates subdirectories under the Users folder and excludes common
    system/admin profiles (Administrator, Admin, Public, Default).

    .PARAMETER Path
    The base path containing user profile folders. Defaults to "$env:SYSTEMDRIVE\Users".

    .EXAMPLE
    Get-UserFolders
    Returns all non-system user folder names from C:\Users.

    .EXAMPLE
    Get-UserFolders -Path 'D:\Users'
    Returns all non-system user folder names from D:\Users.

    .OUTPUTS
    [string[]] Array of user profile folder names.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Get-UserFolders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Retained existing command name for compatibility.')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string] $Path = "$env:SYSTEMDRIVE\Users"
    )

    process {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Warning "User profiles path not found: $Path"
            return
        }

        $ExcludePattern = '^(administrator|admin|public|default)$'

        Get-ChildItem -Directory -LiteralPath $Path -ErrorAction Stop |
            Where-Object { $_.Name -notmatch $ExcludePattern -and (Test-SafeCleanupPath -LiteralPath $_.FullName) } |
            Select-Object -ExpandProperty Name
    }
}
