<#
    .SYNOPSIS
    Tests whether a registry path exists.

    .DESCRIPTION
    Uses PowerShell registry provider semantics so wildcard paths are supported.

    .PARAMETER Path
    Registry path to test.

    .OUTPUTS
    [bool]
#>
function Test-RegistryPathExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Retained existing command name for compatibility.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process {
        try {
            Test-Path -Path $Path -ErrorAction SilentlyContinue
        }
        catch {
            $false
        }
    }
}
