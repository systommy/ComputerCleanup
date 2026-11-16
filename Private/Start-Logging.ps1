<#
    .SYNOPSIS
    Starts a PowerShell transcript log file.

    .DESCRIPTION
    Creates a unique log file in the system temp directory and starts
    a PowerShell transcript. Returns the log file path for later use.

    .PARAMETER LogName
    Base name for the log file. A GUID and .log extension are appended automatically.

    .EXAMPLE
    $LogPath = Start-Logging -LogName 'ComputerCleanup'
    Starts a transcript at C:\Windows\Temp\ComputerCleanup_<unique-id>.log

    .OUTPUTS
    [string] The full path to the log file.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Start-Logging {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Alias('Name')]
        [string] $LogName
    )

    process {
        $FileName = '{0}_{1}.log' -f $LogName, ([guid]::NewGuid().ToString('N'))
        $LogFile  = Join-Path -Path $env:SystemRoot -ChildPath "Temp\$FileName"

        if (-not $PSCmdlet.ShouldProcess($LogFile, 'Start local transcript')) { return }

        try {
            Start-Transcript -LiteralPath $LogFile -NoClobber -ErrorAction Stop | Out-Null
            Write-Verbose "Transcript started: $LogFile"
        }
        catch {
            throw
        }

        $LogFile
    }
}
