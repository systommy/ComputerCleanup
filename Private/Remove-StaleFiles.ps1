function Remove-StaleFiles {
    <#
    .SYNOPSIS
    Removes eligible files and empty descendant directories from literal targets.
    .DESCRIPTION
    Never recursively deletes directories. New, locked and unmatched files survive
    regardless of parent age. Rechecks ancestors immediately before deletion.
    .PARAMETER Paths
    Absolute local literal targets. Target directories themselves are retained.
    .PARAMETER CutoffDate
    Required with age filtering; comparison is strictly older than.
    .PARAMETER AgeMode
    None, CreationAndLastWrite, or compatibility mode CreationAndLastAccess.
    .PARAMETER FileNamePattern
    Pattern applied to file names only, never expanded as a filesystem path.
    .PARAMETER MinimumBytes
    Exclusive size threshold. Minus one includes empty files.
    .EXAMPLE
    Remove-StaleFiles -Paths 'C:\CleanupFixture\cache' -WhatIf
    .OUTPUTS
    None
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Retained existing command name for compatibility.')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $Paths,
        [Nullable[datetime]] $CutoffDate,
        [ValidateSet('None','CreationAndLastAccess','CreationAndLastWrite')][string] $AgeMode = 'None',
        [string] $FileNamePattern = '*',
        [ValidateRange(-1, [long]::MaxValue)][long] $MinimumBytes = -1
    )
    if ($AgeMode -ne 'None' -and $null -eq $CutoffDate) { throw 'CutoffDate is required for age filtering.' }
    $CutoffUtc = if ($null -ne $CutoffDate) { ([datetime]$CutoffDate).ToUniversalTime() } else { [datetime]::MaxValue }
    foreach ($Target in $Paths) {
        $Entries = @(Get-SafeCleanupItem -LiteralPath $Target)
        foreach ($File in @($Entries | Where-Object { $_ -is [IO.FileInfo] })) {
            if (-not (Test-SafeCleanupPath -LiteralPath $File.FullName)) { continue }
            $File.Refresh()
            if ($File.Name -notlike $FileNamePattern -or $File.Length -le $MinimumBytes) { continue }
            if ($AgeMode -ne 'None') {
                $OtherDate = if ($AgeMode -eq 'CreationAndLastAccess') { $File.LastAccessTimeUtc } else { $File.LastWriteTimeUtc }
                if ($File.CreationTimeUtc -ge $CutoffUtc -or $OtherDate -ge $CutoffUtc) { continue }
            }
            if ($PSCmdlet.ShouldProcess($File.FullName, 'Permanently delete file')) {
                try { [IO.File]::Delete($File.FullName) }
                catch { Write-Error "Could not delete '$($File.FullName)': $($_.Exception.Message)" }
            }
        }
        if ($FileNamePattern -eq '*' -and $MinimumBytes -eq -1) {
            foreach ($Directory in @($Entries | Where-Object { $_ -is [IO.DirectoryInfo] } | Sort-Object { $_.FullName.Length } -Descending)) {
                if ($Directory.FullName.TrimEnd('\') -eq $Target.TrimEnd('\')) { continue }
                if (-not (Test-SafeCleanupPath -LiteralPath $Directory.FullName)) { continue }
                $Directory.Refresh()
                if ($AgeMode -ne 'None' -and ($Directory.CreationTimeUtc -ge $CutoffUtc -or $Directory.LastWriteTimeUtc -ge $CutoffUtc)) { continue }
                if (@(Get-ChildItem -LiteralPath $Directory.FullName -Force -ErrorAction Stop).Count) { continue }
                if ($PSCmdlet.ShouldProcess($Directory.FullName, 'Remove empty directory')) {
                    try { [IO.Directory]::Delete($Directory.FullName, $false) }
                    catch { Write-Error "Could not remove empty directory '$($Directory.FullName)': $($_.Exception.Message)" }
                }
            }
        }
    }
}
