# Get public and private function definition files
$Private = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 -Recurse

# Dot-source private scripts first, then public
($Private + $Public) | ForEach-Object {
    try {
        Write-Verbose "Loading $($_.FullName)"
        . $_.FullName
    }
    catch {
        Write-Warning "Failed to load $($_.FullName): $($_.Exception.Message)"
    }
}

# Only export public functions
Export-ModuleMember -Function $Public.BaseName
