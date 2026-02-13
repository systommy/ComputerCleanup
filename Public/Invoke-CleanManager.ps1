<#
    .SYNOPSIS
    Runs the Windows Disk Cleanup tool with predefined options.

    .DESCRIPTION
    Configures registry keys for Windows Disk Cleanup (cleanmgr.exe) with
    predefined cleanup sections, then runs the tool in automated mode.
    If cleanmgr.exe is not installed (Server 2008 R2), attempts installation.
    Supports -WhatIf and -Confirm.

    Default enabled sections include: Active Setup Temp Folders, BranchCache,
    Device Driver Packages, Downloaded Program Files, Offline Pages Files,
    Old ChkDsk Files, Previous Installations, Service Pack Cleanup, Setup Log Files,
    Temporary Files, Temporary Setup Files, Thumbnail Cache, Update Cleanup,
    Upgrade Discarded Files, Windows Defender, Windows ESD installation files,
    Windows Error Reporting files, and Windows Upgrade Log Files.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Invoke-CleanManager
    Runs Windows Disk Cleanup with predefined options.

    .EXAMPLE
    Invoke-CleanManager -Force
    Runs without confirmation.

    .EXAMPLE
    Invoke-CleanManager -WhatIf
    Shows what would happen without modifying registry or running cleanmgr.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Invoke-CleanManager {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch] $Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Before    = Get-DiskSpace

        $CleanMgrPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\cleanmgr.exe'

        # Check if Disk Cleanup is installed; if not, attempt installation (Server 2008 R2)
        if (-not (Test-Path $CleanMgrPath)) {
            Write-Warning 'Windows Cleanup NOT installed! Trying installation...'
            try {
                $WinsxsCleanMgr = Join-Path -Path $env:SystemRoot -ChildPath 'Winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe'
                $WinsxsMui      = Join-Path -Path $env:SystemRoot -ChildPath 'Winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui'

                if (Test-Path $WinsxsCleanMgr) {
                    Copy-Item $WinsxsCleanMgr -Destination (Join-Path -Path $env:SystemRoot -ChildPath 'System32')
                }
                if (Test-Path $WinsxsMui) {
                    Copy-Item $WinsxsMui -Destination (Join-Path -Path $env:SystemRoot -ChildPath 'System32\en-US')
                }
                elseif (-not (Get-WindowsFeature 'Desktop-Experience')) {
                    Write-Verbose 'Manual file copy failed. Installing Desktop Experience feature...'
                    Install-WindowsFeature 'Desktop-Experience'
                }
            }
            catch {
                Write-Error $_
            }
        }

        # Verify Disk Cleanup is available before continuing
        if (-not (Test-Path $CleanMgrPath)) {
            throw 'Windows Disk Cleanup tool not installed! Aborting...'
        }

        # Enabled sections for Disk Cleanup
        $Sections = @(
            'Active Setup Temp Folders',
            'BranchCache',
            'Device Driver Packages',
            'Downloaded Program Files',
            #'DownloadsFolder',
            'GameNewsFiles',
            'GameStatisticsFiles',
            'GameUpdateFiles',
            #'Memory Dump Files',
            'Offline Pages Files',
            'Old ChkDsk Files',
            'Previous Installations',
            #'Recycle Bin',
            'Service Pack Cleanup',
            'Setup Log Files',
            #'System error memory dump files',
            #'System error minidump files',
            'Temporary Files',
            'Temporary Setup Files',
            #'Temporary Sync Files',
            'Thumbnail Cache',
            'Update Cleanup',
            'Upgrade Discarded Files',
            #'User file versions',
            'Windows Defender',
            'Windows ESD installation files',
            'Windows Error Reporting Archive Files',
            'Windows Error Reporting Queue Files',
            'Windows Error Reporting System Archive Files',
            'Windows Error Reporting System Queue Files',
            'Windows Upgrade Log Files'
        )
    }

    process {
        # Clear current registry entries
        if ($PSCmdlet.ShouldProcess('CleanMgr registry keys', 'Clear existing StateFlags0001')) {
            Write-Verbose 'Clearing current CleanMgr.exe automation settings...'
            $RegistryParams = @{
                Path        = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*'
                Name        = 'StateFlags0001'
                ErrorAction = 'SilentlyContinue'
            }
            [void] (Get-ItemProperty @RegistryParams | Remove-ItemProperty -Name 'StateFlags0001' -ErrorAction SilentlyContinue)
        }

        # Add registry entries for enabled sections
        if ($PSCmdlet.ShouldProcess('CleanMgr registry keys', 'Set StateFlags0001 for enabled sections')) {
            Write-Verbose 'Adding enabled disk cleanup sections...'
            foreach ($Key in $Sections) {
                $RegistryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$Key"
                try {
                    [Microsoft.Win32.Registry]::SetValue(
                        $RegistryPath,
                        'StateFlags0001',
                        1,
                        [Microsoft.Win32.RegistryValueKind]::DWord
                    )
                }
                catch {
                    Write-Verbose "Failed to set StateFlags0001 for '$Key': $($_.Exception.Message)"
                }
            }
        }

        if ($PSCmdlet.ShouldProcess('cleanmgr.exe /sagerun:1', 'Run Disk Cleanup')) {
            try {
                Write-Verbose 'Running CleanMgr.exe...'

                $ExistingDismHostIds = @(
                    Get-Process -Name 'dismhost' -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty Id
                )

                $CleanMgrProcess = Start-Process -FilePath $CleanMgrPath -ArgumentList '/sagerun:1' -NoNewWindow -PassThru
                Wait-Process -Id $CleanMgrProcess.Id -ErrorAction SilentlyContinue

                Write-Verbose 'Waiting for new DismHost cleanup processes to finish...'
                $DismHostTimeoutSeconds = 900
                $Deadline = (Get-Date).AddSeconds($DismHostTimeoutSeconds)

                do {
                    $NewDismHost = @(
                        Get-Process -Name 'dismhost' -ErrorAction SilentlyContinue |
                            Where-Object { $ExistingDismHostIds -notcontains $_.Id }
                    )

                    if ($NewDismHost.Count -eq 0) {
                        break
                    }

                    Start-Sleep -Seconds 1
                }
                while ((Get-Date) -lt $Deadline)

                if ($NewDismHost.Count -gt 0) {
                    Write-Warning 'Timed out waiting for CleanMgr child DismHost process(es). Continuing with remaining cleanup steps.'
                }
            }
            catch {
                Write-Error "Invoke-CleanManager: $($_.Exception.Message)"
            }
        }
    }

    end {
        New-CleanupReport -Name 'CleanManager' -StopWatch $StopWatch -DiskBefore $Before
    }
}

