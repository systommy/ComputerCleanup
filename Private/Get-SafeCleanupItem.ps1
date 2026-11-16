function Get-SafeCleanupItem {
    <#
    .SYNOPSIS
    Enumerates a literal target without descending into reparse points.
    .DESCRIPTION
    Enumerates one level at a time on both supported PowerShell editions.
    .PARAMETER LiteralPath
    Absolute local target.
    .EXAMPLE
    Get-SafeCleanupItem -LiteralPath 'C:\CleanupFixture\cache'
    .OUTPUTS
    System.IO.FileSystemInfo
    #>
    [CmdletBinding()]
    [OutputType([IO.FileSystemInfo])]
    param([Parameter(Mandatory)][string] $LiteralPath)
    $Pending = [Collections.Generic.Stack[string]]::new()
    $Pending.Push($LiteralPath)
    while ($Pending.Count) {
        $Current = $Pending.Pop()
        if (-not (Test-SafeCleanupPath -LiteralPath $Current)) { Write-Verbose "Skipping unsafe path: $Current"; continue }
        $Item = Get-Item -LiteralPath $Current -Force -ErrorAction Stop
        $Item
        if ($Item -is [IO.DirectoryInfo]) {
            foreach ($Child in @(Get-ChildItem -LiteralPath $Current -Force -ErrorAction Stop)) {
                if (-not ($Child.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $Pending.Push($Child.FullName) }
            }
        }
    }
}
