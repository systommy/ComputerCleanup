<#
    .SYNOPSIS
    Main orchestrator function to invoke one or multiple cleanup functions included in this module.

    .DESCRIPTION
    Delegates to specialized cleanup functions based on the switches provided.
    Captures before/after disk space, tracks elapsed time per section, and produces
    a summary report. Optionally sends the report via email. Each cleanup function
    returns a result object that is collected into a results array.

    The -Days parameter controls file age threshold but does NOT apply to
    -BrowserCache, -TeamsCache, -SoftwareDistribution, or -FontCache (those always clean everything).

    Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Days
    Only remove files and folders older than this many days. Defaults to 30.
    Does NOT apply to BrowserCache, TeamsCache, SoftwareDistribution, or FontCache.

    .PARAMETER CleanManager
    Runs the Windows Disk Cleanup tool with predefined options.

    .PARAMETER SystemTemp
    Removes common system-wide temporary files and folders older than Days.

    .PARAMETER SoftwareDistribution
    Cleans the SoftwareDistribution\Download folder.

    .PARAMETER FontCache
    Clears user font cache files and restarts the Font Cache service.

    .PARAMETER BrowserCache
    Clears browser cache files for all users. Stops running browser processes.

    .PARAMETER TeamsCache
    Clears Microsoft Teams cache files for all users. Stops running Teams processes.

    .PARAMETER Force
    Suppresses all confirmation prompts.

    .PARAMETER UserTemp
    Removes common temporary files from user profiles older than Days.

    .PARAMETER UserDownloads
    Removes large archive/installer files from users' Downloads folders.

    .PARAMETER ArchiveTypes
    File extensions to consider as archive files when using -UserDownloads.
    Defaults to zip, rar, 7z, iso.

    .PARAMETER RecycleBin
    Clears the Windows Recycle Bin.

    .PARAMETER MailReport
    Send an HTML email report after cleanup completes.

    .PARAMETER SmtpServer
    SMTP server address for email reports.

    .PARAMETER SmtpPort
    SMTP server port for email reports.

    .PARAMETER FromAddress
    Sender email address for the report.

    .PARAMETER ToAddress
    Recipient email address for the report.

    .EXAMPLE
    Invoke-ComputerCleanup -Days 30 -UserTemp -SystemTemp -CleanManager -SoftwareDistribution -RecycleBin
    Runs Disk Cleanup, cleans user and system temp files older than 30 days, cleans
    SoftwareDistribution, and empties the Recycle Bin.

    .EXAMPLE
    Invoke-ComputerCleanup -Days 30 -BrowserCache -TeamsCache -Force
    Clears browser and Teams cache for all users without confirmation prompts.

    .EXAMPLE
    Invoke-ComputerCleanup -Days 30 -UserTemp -SystemTemp -WhatIf
    Shows what would be cleaned without actually removing any files.

    .OUTPUTS
    [PSCustomObject[]] Array of per-section cleanup results, plus console summary output.

    .LINK
    https://systom.dev

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Invoke-ComputerCleanup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Days = 30,

        [Parameter()]
        [switch] $CleanManager,

        [Parameter()]
        [switch] $SystemTemp,

        [Parameter()]
        [switch] $SoftwareDistribution,

        [Parameter()]
        [switch] $FontCache,

        [Parameter()]
        [switch] $BrowserCache,

        [Parameter()]
        [switch] $TeamsCache,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $UserTemp,

        [Parameter()]
        [switch] $UserDownloads,

        [Parameter()]
        [string[]] $ArchiveTypes = @('zip', 'rar', '7z', 'iso'),

        [Parameter()]
        [switch] $RecycleBin,

        [Parameter()]
        [switch] $MailReport,

        [Parameter()]
        [string] $SmtpServer,

        [Parameter()]
        [int] $SmtpPort,

        [Parameter()]
        [string] $FromAddress,

        [Parameter()]
        [string] $ToAddress
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        $InformationPreference = 'Continue'

        # Start logging
        $LogFile = Start-Logging -LogName 'ComputerCleanup'

        Assert-RunAsAdministrator

        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Before    = Get-DiskSpace
        $Results   = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        # Display parameter summary
        $ParamReport      = [ordered]@{}
        $RiskyParamReport = [ordered]@{}

        switch ($PSBoundParameters.Keys) {
            'Days'                 { $ParamReport.Days = "Files older than $Days days will be removed. Does NOT apply to BrowserCache, TeamsCache, SoftwareDistribution, FontCache." }
            'CleanManager'         { $ParamReport.CleanManager = 'Runs the Windows Disk Cleanup tool with predefined options.' }
            'SystemTemp'           { $ParamReport.SystemTemp = "Removes common system-wide temporary files older than $Days days." }
            'UserTemp'             { $ParamReport.UserTemp = "Removes common temporary files from user profiles older than $Days days." }
            'UserDownloads'        { $ParamReport.UserDownloads = "Removes large archive/installer files older than $Days days from Downloads folders."
                                     $RiskyParamReport.UserDownloads = "This will remove users' personal files! Please make sure they are informed." }
            'SoftwareDistribution' { $ParamReport.SoftwareDistribution = 'Cleans the SoftwareDistribution\Download folder.' }
            'FontCache'            { $ParamReport.FontCache = 'Removes font cache files and restarts the Font Cache service.' }
            'TeamsCache'           { $ParamReport.TeamsCache = 'Clears Microsoft Teams cache files for all users.'
                                     $RiskyParamReport.TeamsCache = 'This will stop ALL running Teams processes. Running outside of working hours is advised.' }
            'BrowserCache'         { $ParamReport.BrowserCache = 'Clears cache files for all browsers.'
                                     $RiskyParamReport.BrowserCache = 'This will stop ALL running browser processes. Running outside of working hours is advised.' }
            'RecycleBin'           { $ParamReport.RecycleBin = 'Clears the Windows Recycle Bin.' }
        }

        if ($ParamReport.Count -gt 0) {
            Write-Verbose ''.PadLeft(76, '-')
            Write-Verbose '=== SCRIPT OPTIONS SUMMARY:'
            $ParamReport.Keys | ForEach-Object {
                Write-Verbose "  $_ : $($ParamReport[$_])"
            }

            if ($RiskyParamReport.Count -gt 0 -and -not $Force) {
                Write-Warning 'Some commands are dangerous to execute on a live environment. Please review:'
                $RiskyParamReport.Keys | ForEach-Object {
                    Write-Warning "  $_ : $($RiskyParamReport[$_])"
                }
            }
            Write-Verbose ''.PadLeft(76, '-')
        }

        # Execute cleanup functions based on switches
        if ($CleanManager) {
            try {
                Write-Verbose '=== STARTED : Windows Disk Cleanup (this may take a while)'
                $Result = Invoke-CleanManager -Force:$Force
                if ($Result) { $Results.Add($Result) }
                Write-Verbose '=== FINISHED: Windows Disk Cleanup'
            }
            catch {
                Write-Error $_
            }
        }

        if ($UserTemp) {
            $UserParams = @{
                Days      = $Days
                TempFiles = $true
                Force     = [bool]$Force
            }
            if ($UserDownloads) {
                $UserParams.Downloads    = $true
                $UserParams.ArchiveFiles = $true
                $UserParams.ArchiveTypes = $ArchiveTypes
            }

            Write-Verbose '=== STARTED : Cleaning User Profiles'
            $Result = Optimize-UserProfiles @UserParams
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning User Profiles'
        }

        if ($SystemTemp) {
            Write-Verbose '=== STARTED : Cleaning System files'
            $Result = Optimize-SystemFiles -Days $Days -TempFiles -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning System files'
        }

        if ($SoftwareDistribution) {
            Write-Verbose '=== STARTED : Cleaning SoftwareDistribution Download folder'
            $Result = Clear-SoftwareDistribution -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning SoftwareDistribution Download folder'
        }

        if ($FontCache) {
            Write-Verbose '=== STARTED : Cleaning Font Cache'
            $Result = Clear-FontCache -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning Font Cache'
        }

        if ($TeamsCache) {
            Write-Verbose '=== STARTED : Cleaning Teams cache'
            $Result = Clear-TeamsCache -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning Teams cache'
        }

        if ($BrowserCache) {
            Write-Verbose '=== STARTED : Cleaning Browser Cache'
            $Result = Clear-BrowserCache -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning Browser Cache'
        }

        if ($RecycleBin) {
            Write-Verbose '=== STARTED : Cleaning Recycle Bin'
            $Result = Optimize-SystemFiles -Days $Days -RecycleBin -Force:$Force
            if ($Result) { $Results.Add($Result) }
            Write-Verbose '=== FINISHED: Cleaning Recycle Bin'
        }

        # Reporting / Finalization
        $After = Get-DiskSpace
        $StopWatch.Stop()

        $TotalSeconds = '{0:00.00} sec' -f $StopWatch.Elapsed.TotalSeconds
        $TotalMinutes = '{0:00} min' -f $StopWatch.Elapsed.TotalMinutes
        $SpaceBefore  = "$($Before.FreeSpaceGB) GB"
        $SpaceAfter   = "$($After.FreeSpaceGB) GB"
        $TotalCleaned = '{0:00.00} GB' -f ($After.FreeSpaceGB - $Before.FreeSpaceGB)

        Write-Information ''.PadLeft(76, '-')
        Write-Information '=== SCRIPT FINISHED'
        Write-Information "Current Time       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Information "Elapsed Time       : $TotalSeconds / $TotalMinutes"
        Write-Information "Free space BEFORE  : $SpaceBefore"
        Write-Information "Free space AFTER   : $SpaceAfter"
        Write-Information "TOTAL space cleaned: $TotalCleaned"
        Write-Information ''.PadLeft(76, '-')
        Write-Information '=== PER-SECTION BREAKDOWN'
        $Results | Format-Table -AutoSize | Out-String | Write-Information
        Write-Information ''.PadLeft(76, '-')
    }

    end {
        Stop-Transcript

        if ($MailReport) {
            $Summary = [PSCustomObject]@{
                TotalSeconds = $TotalSeconds
                TotalMinutes = $TotalMinutes
                SpaceBefore  = $SpaceBefore
                SpaceAfter   = $SpaceAfter
                TotalCleaned = $TotalCleaned
            }

            $MailBody = New-HtmlCleanupReport -CleanupResults $Results.ToArray() -Summary $Summary

            $MailParams = @{
                SmtpServer  = $SmtpServer
                Port        = $SmtpPort
                From        = $FromAddress
                To          = $ToAddress
                Subject     = "$([System.Net.Dns]::GetHostEntry($env:ComputerName).HostName) - Disk Cleanup report"
                Body        = $MailBody
                BodyAsHtml  = $true
                Attachments = $LogFile
            }

            Write-Verbose "Sending e-mail report to $($MailParams.To)"
            Send-MailMessage @MailParams -WarningAction SilentlyContinue
        }

        $Results.ToArray()
    }
}
