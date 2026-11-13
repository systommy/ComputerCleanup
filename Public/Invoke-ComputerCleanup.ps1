<#
    .SYNOPSIS
    Main orchestrator function to invoke one or multiple cleanup functions included in this module.

    .DESCRIPTION
    Delegates to specialized cleanup functions based on the switches provided.
    Captures before/after disk space, tracks elapsed time per section, and produces
    a summary report. Optionally sends the report via email. Each cleanup function
    returns a result object that is collected into a results array.

    The -Days parameter controls file age threshold but does NOT apply to
    -BrowserCache, -TeamsCache, -SoftwareDistribution, -FontCache, -RecycleBin or -CleanManager.

    Supports -WhatIf, -Confirm, and -Force.

    .PARAMETER Days
    Only remove files and folders older than this many days. Defaults to 30.
    Does NOT apply to BrowserCache, TeamsCache, SoftwareDistribution, FontCache, RecycleBin or CleanManager.

    .PARAMETER CleanManager
    Runs installed Windows Disk Cleanup with Temporary Files and Thumbnail Cache selected.

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
    Suppresses implicit confirmation; explicit -Confirm and -WhatIf take precedence.

    .PARAMETER UserTemp
    Removes common temporary files from user profiles older than Days.

    .PARAMETER UserDownloads
    Removes selected archives larger than 500MB from Downloads, independently of UserTemp.

    .PARAMETER ArchiveTypes
    File extensions to consider as archive files when using -UserDownloads.
    Defaults to zip, rar, 7z, iso.

    .PARAMETER RecycleBin
    Clears the Windows Recycle Bin.

    .PARAMETER MailReport
    Send a separately confirmed HTML report and private transcript through the legacy SMTP path. Requires all SMTP/address parameters.

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
        [ValidatePattern('^[A-Za-z0-9]+$')]
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

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) { $ConfirmPreference = 'None' }
    Assert-RunAsAdministrator
    $Selected = @('CleanManager','UserTemp','UserDownloads','SystemTemp','SoftwareDistribution','FontCache','TeamsCache','BrowserCache','RecycleBin' | Where-Object { $PSBoundParameters.ContainsKey($_) -and $PSBoundParameters[$_] })
    if (-not $Selected.Count) { throw 'Select at least one cleanup operation.' }
    if ($MailReport -and (-not $SmtpServer -or $SmtpPort -lt 1 -or $SmtpPort -gt 65535 -or -not $FromAddress -or -not $ToAddress)) {
        throw 'MailReport requires SmtpServer, SmtpPort (1-65535), FromAddress and ToAddress.'
    }
    # One approval covers the selected batch, including logging. All actual child
    # actions still have their own ShouldProcess guards for direct invocation.
    $Action = 'Permanently clean selected data, affect selected processes/services, and create a local transcript'
    if (-not $PSCmdlet.ShouldProcess(($Selected -join ', '), $Action)) { return }
    $LogFile = $null
    $Results = [Collections.Generic.List[PSCustomObject]]::new()
    $Before = Get-DiskSpace
    $StopWatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $LogFile = Start-Logging -LogName 'ComputerCleanup' -Confirm:$false
        $Child = @{ Confirm = $false; ErrorAction = 'Stop' }
        if ($CleanManager) { $Results.Add((Invoke-CleanManager @Child)) }
        if ($UserTemp -or $UserDownloads) {
            $Results.Add((Optimize-UserProfiles -Days $Days -TempFiles:$UserTemp -Downloads:$UserDownloads -ArchiveFiles:$UserDownloads -ArchiveTypes $ArchiveTypes @Child))
        }
        if ($SystemTemp -or $RecycleBin) {
            $Results.Add((Optimize-SystemFiles -Days $Days -TempFiles:$SystemTemp -RecycleBin:$RecycleBin @Child))
        }
        if ($SoftwareDistribution) { $Results.Add((Clear-SoftwareDistribution @Child)) }
        if ($FontCache) { $Results.Add((Clear-FontCache @Child)) }
        if ($TeamsCache) { $Results.Add((Clear-TeamsCache @Child)) }
        if ($BrowserCache) { $Results.Add((Clear-BrowserCache @Child)) }
    }
    finally {
        $StopWatch.Stop()
        if ($LogFile) { Stop-Transcript -ErrorAction Stop | Out-Null }
    }
    if ($MailReport -and $PSCmdlet.ShouldProcess($ToAddress, 'Send cleanup report and transcript over configured SMTP')) {
        $After = Get-DiskSpace
        $Summary = [PSCustomObject]@{
            TotalSeconds = '{0:F2} sec' -f $StopWatch.Elapsed.TotalSeconds
            TotalMinutes = '{0:F2} min' -f $StopWatch.Elapsed.TotalMinutes
            SpaceBefore = "$($Before.FreeSpaceGB) GB"
            SpaceAfter = "$($After.FreeSpaceGB) GB"
            TotalCleaned = '{0:F2} GB' -f ($After.FreeSpaceGB - $Before.FreeSpaceGB)
        }
        $MailBody = New-HtmlCleanupReport -CleanupResults $Results.ToArray() -Summary $Summary
        # Compatibility only: prefer consuming returned objects with your approved mail client.
        Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort -From $FromAddress -To $ToAddress -Subject 'ComputerCleanup report' -Body $MailBody -BodyAsHtml -Attachments $LogFile -ErrorAction Stop
    }
    $Results.ToArray()
}
