<#
    .SYNOPSIS
    Clears browser cache files for all users.

    .DESCRIPTION
    Removes cached files for Microsoft Edge, Internet Explorer, Google Chrome,
    and Firefox across all user profiles. Kills running browser processes before
    cleaning. Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Browsers
    Which browsers to clean. Valid values: All, Chrome, Edge, IE, Firefox.
    Defaults to 'All'.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Clear-BrowserCache
    Clears cache for all browsers (prompts for confirmation).

    .EXAMPLE
    Clear-BrowserCache -Browsers Chrome, Edge -Force
    Clears Chrome and Edge cache without confirmation.

    .EXAMPLE
    Clear-BrowserCache -WhatIf
    Shows what would be cleaned without actually removing files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Clear-BrowserCache {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('All', 'Chrome', 'Edge', 'IE', 'Firefox')]
        [Alias('Browser')]
        [string[]] $Browsers = 'All',

        [Parameter()]
        [switch] $Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        Assert-RunAsAdministrator

        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Before    = Get-DiskSpace
        $Users     = Get-UserFolders

        $CleanupDefinitions = Get-CleanupDefinition
        $BrowserDefinitions = $CleanupDefinitions.Browsers

        if ($Browsers -contains 'All') {
            $SelectedBrowserNames = @('Chrome', 'Edge', 'IE', 'Firefox')
        }
        else {
            $SelectedBrowserNames = $Browsers
        }

        $EnabledBrowserNames = New-Object System.Collections.Generic.List[string]
        foreach ($BrowserName in $SelectedBrowserNames) {
            $Definition = $BrowserDefinitions[$BrowserName]
            if ($null -eq $Definition) {
                continue
            }

            $IsInstalled = $false
            foreach ($RegistryPath in @($Definition.RegistryDetection)) {
                if (Test-RegistryPathExists -Path $RegistryPath) {
                    $IsInstalled = $true
                    break
                }
            }

            if ($IsInstalled) {
                $EnabledBrowserNames.Add($BrowserName)
            }
            else {
                Write-Verbose "Skipping browser '$BrowserName' because no installation registry keys were found."
            }
        }

        $BrowserProcesses = @(
            foreach ($BrowserName in $EnabledBrowserNames) {
                @($BrowserDefinitions[$BrowserName].ProcessName)
            }
        ) | Select-Object -Unique
    }

    process {
        Write-Verbose 'Starting browser cache cleanup process...'

        $ContinueProcessStop = $false
        try {
            $ContinueProcessStop = $PSCmdlet.ShouldContinue('Kill all browser processes? This will close open browser windows.', 'Clear-BrowserCache')
        }
        catch {
            Write-Verbose "Process confirmation prompt unavailable: $($_.Exception.Message)"
        }

        if ($ContinueProcessStop) {
            Stop-ProcessGracefully -ProcessNames $BrowserProcesses
        }

        foreach ($UserName in $Users) {
            $UserProfilePath = Join-Path -Path "$env:SYSTEMDRIVE\Users" -ChildPath $UserName

            foreach ($BrowserName in $EnabledBrowserNames) {
                $Definition = $BrowserDefinitions[$BrowserName]
                $FoldersToClean = Get-ExpandedUserRelativePaths -UserProfilePath $UserProfilePath -RelativePaths @($Definition.RelativePaths)

                foreach ($FolderToClean in $FoldersToClean) {
                    if ($PSCmdlet.ShouldProcess($FolderToClean, 'Remove cached files')) {
                        Remove-StaleFiles -Paths @($FolderToClean) -AgeMode 'None'
                    }
                }
            }

            Write-Verbose "Finished removing browser cache files for $UserName."
        }
    }

    end {
        New-CleanupReport -Name 'BrowserCache' -StopWatch $StopWatch -DiskBefore $Before
    }
}
