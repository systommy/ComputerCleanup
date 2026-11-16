function Invoke-CleanManager {
    <#
    .SYNOPSIS
    Runs installed Windows Disk Cleanup with a temporary, unused preset.
    .DESCRIPTION
    Does not install Windows features. Selects only Temporary Files and Thumbnail
    Cache by default. Explicit extra sections can delete update rollback material.
    Removes its own temporary flags in finally and preserves existing presets.
    .PARAMETER Sections
    Explicit built-in categories; only installed matching handlers are selected.
    .PARAMETER Force
    Suppress implicit confirmation. Explicit -Confirm and -WhatIf take precedence.
    .EXAMPLE
    Invoke-CleanManager -WhatIf
    .EXAMPLE
    Invoke-CleanManager -Sections 'Temporary Files','Thumbnail Cache' -Confirm
    .OUTPUTS
    PSCustomObject with duration and observed disk-space delta.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [ValidateSet('Temporary Files','Thumbnail Cache','Downloaded Program Files','Windows Error Reporting Archive Files','Windows Error Reporting Queue Files','Update Cleanup','Previous Installations','Device Driver Packages')]
        [string[]] $Sections = @('Temporary Files','Thumbnail Cache'),
        [switch] $Force
    )
    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) { $ConfirmPreference = 'None' }
    Assert-RunAsAdministrator
    $StopWatch = [Diagnostics.Stopwatch]::StartNew()
    $Before = Get-DiskSpace
    $Executable = Join-Path $env:SystemRoot 'System32\cleanmgr.exe'
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'cleanmgr.exe is unavailable. No installation will be attempted.' }
    if ($PSCmdlet.ShouldProcess(($Sections -join ', '), 'Configure temporary preset and run Windows Disk Cleanup')) {
        $Mutex = [Threading.Mutex]::new($false, 'Local\ComputerCleanup-CleanManager')
        $Acquired = $false
        $Touched = [Collections.Generic.List[string]]::new()
        try {
            $Acquired = $Mutex.WaitOne(0)
            if (-not $Acquired) { throw 'Another ComputerCleanup Disk Cleanup run is active.' }
            $Keys = @(Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' -ErrorAction Stop)
            $Selected = @($Keys | Where-Object { $_.PSChildName -in $Sections })
            if (-not $Selected.Count) { throw 'None of the selected Disk Cleanup handlers are installed.' }
            $Used = @($Keys | ForEach-Object { (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop).PSObject.Properties.Name })
            $Preset = 9000
            while ($Preset -le 9999 -and ('StateFlags{0:D4}' -f $Preset) -in $Used) { $Preset++ }
            if ($Preset -gt 9999) { throw 'No unused Disk Cleanup preset is available.' }
            $Flag = 'StateFlags{0:D4}' -f $Preset
            foreach ($Key in $Selected) {
                $Touched.Add($Key.PSPath)
                New-ItemProperty -LiteralPath $Key.PSPath -Name $Flag -Value 2 -PropertyType DWord -ErrorAction Stop | Out-Null
            }
            $Process = Start-Process -FilePath $Executable -ArgumentList "/sagerun:$Preset" -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            if ($Process.ExitCode -ne 0) { throw "Disk Cleanup exited with code $($Process.ExitCode)." }
        }
        finally {
            $RestoreFailures = @()
            foreach ($Path in $Touched) {
                try { Remove-ItemProperty -LiteralPath $Path -Name $Flag -ErrorAction Stop }
                catch { $RestoreFailures += $Path; Write-Warning "Could not remove temporary Disk Cleanup flag from '$Path'." }
            }
            if ($Acquired) { $Mutex.ReleaseMutex() }
            $Mutex.Dispose()
            if ($RestoreFailures.Count) { throw 'Temporary Disk Cleanup flags could not all be removed; inspect the reported registry paths.' }
        }
    }
    New-CleanupReport -Name 'CleanManager' -StopWatch $StopWatch -DiskBefore $Before
}
