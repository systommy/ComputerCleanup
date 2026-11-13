function Get-ExpandedUserRelativePaths {
    <#
    .SYNOPSIS
    Expands relative patterns one component at a time beneath a profile.
    .DESCRIPTION
    Rejects rooted paths, parent traversal and reparse points before descending.
    .PARAMETER UserProfilePath
    Absolute profile root.
    .PARAMETER RelativePaths
    Profile-relative patterns from reviewed cleanup definitions.
    .EXAMPLE
    Get-ExpandedUserRelativePaths -UserProfilePath 'C:\Users\Example' -RelativePaths 'AppData\Local\Temp'
    .OUTPUTS
    System.String
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Retained existing command name for compatibility.')]
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $UserProfilePath, [Parameter(Mandatory)][string[]] $RelativePaths)
    if (-not (Test-SafeCleanupPath -LiteralPath $UserProfilePath)) { return }
    $Resolved = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Relative in $RelativePaths) {
        if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative.Contains(':')) { throw 'Cleanup patterns must stay beneath the user profile.' }
        $Parents = @($UserProfilePath)
        foreach ($Part in ($Relative -split '[\\/]')) {
            if ([string]::IsNullOrWhiteSpace($Part) -or $Part -eq '.') { throw 'Empty or dot cleanup components are not allowed.' }
            $Next = @()
            foreach ($Parent in $Parents) {
                if (-not (Test-SafeCleanupPath -LiteralPath $Parent)) { continue }
                $Next += @(Get-ChildItem -LiteralPath $Parent -Force -ErrorAction Stop | Where-Object { $_.Name -like $Part -and (Test-SafeCleanupPath -LiteralPath $_.FullName) } | Select-Object -ExpandProperty FullName)
            }
            $Parents = $Next
        }
        foreach ($Path in $Parents) { [void]$Resolved.Add($Path) }
    }
    $Resolved | Sort-Object
}
