<#
    .SYNOPSIS
    Starts a PowerShell transcript log file.

    .DESCRIPTION
    Creates a timestamped log file in the system temp directory and starts
    a PowerShell transcript. Returns the log file path for later use.

    .PARAMETER LogName
    Base name for the log file. A timestamp and .log extension are appended automatically.

    .EXAMPLE
    $LogPath = Start-Logging -LogName 'ComputerCleanup'
    Starts a transcript at C:\Windows\Temp\ComputerCleanup_2024-01-15T143022.log

    .OUTPUTS
    [string] The full path to the log file.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Start-Logging {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Alias('Name')]
        [string] $LogName
    )

    process {
        $FileName = '{0}_{1}.log' -f $LogName, (Get-Date -Format 'yyyy-MM-ddTHHmmss')
        $LogFile  = Join-Path -Path $env:SystemRoot -ChildPath "Temp\$FileName"

        try {
            Start-Transcript -Path $LogFile | Out-Null
            Write-Verbose "Transcript started: $LogFile"
        }
        catch {
            Write-Error $_
        }

        $LogFile
    }
}
