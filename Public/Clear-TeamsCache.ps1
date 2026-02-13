<#
    .SYNOPSIS
    Clears Microsoft Teams cache files for all users.

    .DESCRIPTION
    Kills running Teams processes and removes Teams cache directories
    (blob_storage, databases, cache, gpucache, Indexeddb, Local Storage, tmp)
    across all user profiles. Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .EXAMPLE
    Clear-TeamsCache
    Clears Teams cache for all users (prompts for confirmation).

    .EXAMPLE
    Clear-TeamsCache -Force
    Clears Teams cache without confirmation.

    .EXAMPLE
    Clear-TeamsCache -WhatIf
    Shows what would be cleaned without actually removing files.

    .OUTPUTS
    [PSCustomObject] Cleanup result with Name, Duration, SpaceBeforeGB, SpaceAfterGB, SpaceCleanedGB.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Clear-TeamsCache {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
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
        $TeamsDefinitions = $CleanupDefinitions.Teams
        $TeamVariants = @('Classic', 'New')

        $EnabledTeamVariants = New-Object System.Collections.Generic.List[string]
        foreach ($VariantName in $TeamVariants) {
            $Definition = $TeamsDefinitions[$VariantName]
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
                $EnabledTeamVariants.Add($VariantName)
            }
            else {
                Write-Verbose "Skipping Teams variant '$VariantName' because no installation registry keys were found."
            }
        }

        $TeamsProcesses = @(
            foreach ($VariantName in $EnabledTeamVariants) {
                @($TeamsDefinitions[$VariantName].ProcessName)
            }
        ) | Select-Object -Unique
    }

    process {
        Write-Verbose 'Starting Teams Cache cleanup process...'

        $ContinueProcessStop = $false
        try {
            $ContinueProcessStop = $PSCmdlet.ShouldContinue('Kill all Teams processes? This will close open Teams windows.', 'Clear-TeamsCache')
        }
        catch {
            Write-Verbose "Process confirmation prompt unavailable: $($_.Exception.Message)"
        }

        if ($ContinueProcessStop) {
            Stop-ProcessGracefully -ProcessNames $TeamsProcesses
        }

        foreach ($UserName in $Users) {
            $UserProfilePath = Join-Path -Path "$env:SYSTEMDRIVE\Users" -ChildPath $UserName

            foreach ($VariantName in $EnabledTeamVariants) {
                $Definition = $TeamsDefinitions[$VariantName]
                $FoldersToClean = Get-ExpandedUserRelativePaths -UserProfilePath $UserProfilePath -RelativePaths @($Definition.RelativePaths)

                foreach ($FolderToClean in $FoldersToClean) {
                    if ($PSCmdlet.ShouldProcess($FolderToClean, 'Remove Teams cache files')) {
                        Remove-StaleFiles -Paths @($FolderToClean) -AgeMode 'None'
                    }
                }
            }

            Write-Verbose "Finished removing Teams Cache files for $UserName."
        }
    }

    end {
        New-CleanupReport -Name 'TeamsCache' -StopWatch $StopWatch -DiskBefore $Before
    }
}
