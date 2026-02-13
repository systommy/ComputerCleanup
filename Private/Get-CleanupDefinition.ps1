<#
    .SYNOPSIS
    Loads cleanup target definitions from JSON.

    .DESCRIPTION
    Reads CleanupTargets.json and returns a nested hashtable for internal
    lookup by cleanup providers (Browsers and Teams). Results are cached in
    script scope for repeated calls in the same module session.

    .PARAMETER Path
    Optional path to the cleanup definition JSON file.

    .OUTPUTS
    [hashtable]
#>
function Get-CleanupDefinition {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string] $Path = (Join-Path -Path $PSScriptRoot -ChildPath '..\CleanupTargets.json')
    )

    process {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Cleanup definitions file not found: $Path"
        }

        $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

        if (
            $script:CleanupDefinitionsCache -and
            $script:CleanupDefinitionsPath -and
            ($script:CleanupDefinitionsPath -eq $ResolvedPath)
        ) {
            return $script:CleanupDefinitionsCache
        }

        try {
            $RawJson = Get-Content -LiteralPath $ResolvedPath -Raw -Encoding UTF8 -ErrorAction Stop
            $ParsedJson = $RawJson | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Failed to load cleanup definitions from '$ResolvedPath': $($_.Exception.Message)"
        }

        function ConvertTo-NestedHashtable {
            param(
                [Parameter(Mandatory)]
                [object] $InputObject
            )

            if ($null -eq $InputObject) {
                return $null
            }

            if ($InputObject -is [System.Collections.IDictionary]) {
                $Dictionary = @{}
                foreach ($Key in $InputObject.Keys) {
                    $Dictionary[$Key] = ConvertTo-NestedHashtable -InputObject $InputObject[$Key]
                }
                return $Dictionary
            }

            if ($InputObject -is [PSCustomObject]) {
                $Dictionary = @{}
                foreach ($Property in $InputObject.PSObject.Properties) {
                    $Dictionary[$Property.Name] = ConvertTo-NestedHashtable -InputObject $Property.Value
                }
                return $Dictionary
            }

            if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
                $ArrayValues = New-Object System.Collections.Generic.List[object]
                foreach ($Value in $InputObject) {
                    $ArrayValues.Add((ConvertTo-NestedHashtable -InputObject $Value))
                }
                return $ArrayValues.ToArray()
            }

            return $InputObject
        }

        $Definitions = ConvertTo-NestedHashtable -InputObject $ParsedJson

        if (-not $Definitions.ContainsKey('Browsers') -or -not $Definitions.ContainsKey('Teams')) {
            throw "Cleanup definitions in '$ResolvedPath' are missing required keys: Browsers and Teams"
        }

        $script:CleanupDefinitionsPath = $ResolvedPath
        $script:CleanupDefinitionsCache = $Definitions

        $Definitions
    }
}
