# Loading failure must abort import; partial exports are unsafe.
$Private = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter *.ps1 -ErrorAction Stop | Sort-Object Name)
$Public = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 -ErrorAction Stop | Sort-Object Name)
foreach ($File in ($Private + $Public)) { . $File.FullName }
Export-ModuleMember -Function $Public.BaseName
