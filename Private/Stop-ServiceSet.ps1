<#
    .SYNOPSIS
    Stops a service set and returns services that were originally running.

    .DESCRIPTION
    Captures running state before stop and only attempts to stop running
    services. Returned names are intended for restart later.

    .PARAMETER ServiceNames
    Service names to evaluate and stop.

    .OUTPUTS
    [string[]]
#>
function Stop-ServiceSet {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ServiceNames
    )

    process {
        $RunningServiceNames = New-Object System.Collections.Generic.List[string]
        $UniqueServiceNames = $ServiceNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

        foreach ($ServiceName in $UniqueServiceNames) {
            $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($null -eq $Service) {
                continue
            }

            if ($Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                $RunningServiceNames.Add($ServiceName)
                try {
                    Write-Verbose "Stopping service '$ServiceName'..."
                    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to stop service '$ServiceName': $($_.Exception.Message)"
                }
            }
        }

        $RunningServiceNames.ToArray()
    }
}
