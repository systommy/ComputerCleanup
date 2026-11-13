function Test-SafeCleanupPath {
    <#
    .SYNOPSIS
    Rejects nonlocal paths, volume roots and reparse points in every ancestor.
    .DESCRIPTION
    Checks the current filesystem state; does not eliminate concurrent path replacement races.
    .PARAMETER LiteralPath
    Absolute local literal path.
    .EXAMPLE
    Test-SafeCleanupPath -LiteralPath 'C:\CleanupFixture\cache'
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string] $LiteralPath)
    if ($LiteralPath -notmatch '^[A-Za-z]:[\\/]' -or $LiteralPath.Substring(2).Contains(':') -or $LiteralPath -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
    $FullPath = [IO.Path]::GetFullPath($LiteralPath)
    $Root = [IO.Path]::GetPathRoot($FullPath)
    if ($FullPath.TrimEnd('\', '/') -eq $Root.TrimEnd('\', '/')) { return $false }
    $Cursor = $FullPath
    while ($Cursor -and $Cursor -ne $Root) {
        try { $Item = Get-Item -LiteralPath $Cursor -Force -ErrorAction Stop }
        catch { return $false }
        if ($Item.PSProvider.Name -ne 'FileSystem' -or ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $Cursor = [IO.Path]::GetDirectoryName($Cursor.TrimEnd('\', '/'))
    }
    return $true
}
