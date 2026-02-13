<#
    .SYNOPSIS
    Expands user-relative cleanup paths into concrete filesystem paths.

    .DESCRIPTION
    Joins each relative path to a user profile path and resolves wildcards.
    Returns existing full paths only, de-duplicated case-insensitively.

    .PARAMETER UserProfilePath
    Full path to the user profile root (for example C:\Users\jdoe).

    .PARAMETER RelativePaths
    Relative paths under the profile root. Wildcards are supported.

    .OUTPUTS
    [string[]]
#>
function Get-ExpandedUserRelativePaths {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $UserProfilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $RelativePaths
    )

    process {
        $ResolvedPaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($RelativePath in $RelativePaths) {
            $CandidatePath = Join-Path -Path $UserProfilePath -ChildPath $RelativePath
            $HasWildcard = $RelativePath -match '[\*\?\[]'

            if ($HasWildcard) {
                $Items = Get-Item -Path $CandidatePath -Force -ErrorAction SilentlyContinue
            }
            else {
                $Items = Get-Item -LiteralPath $CandidatePath -Force -ErrorAction SilentlyContinue
            }

            foreach ($Item in @($Items)) {
                [void] $ResolvedPaths.Add($Item.FullName)
            }
        }

        @($ResolvedPaths)
    }
}
