function Stop-ServiceSet {
    <#
    .SYNOPSIS
    Stops a service set, rolling back partial stops on failure.
    .DESCRIPTION
    Refuses transitional states and dependent-service force stops. Caller restores
    returned originally running services in finally.
    .PARAMETER ServiceNames
    Explicit service names.
    .EXAMPLE
    Stop-ServiceSet -ServiceNames 'ExampleService' -WhatIf
    .OUTPUTS
    System.String
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([string])]
    param([Parameter(Mandatory)][string[]] $ServiceNames)
    $Restore = [Collections.Generic.List[string]]::new()
    try {
        foreach ($Name in ($ServiceNames | Select-Object -Unique)) {
            $Service = Get-Service -Name $Name -ErrorAction Stop
            if ($Service.Status -notin @('Running', 'Stopped')) { throw "Service '$Name' is in a transitional state." }
            if ($Service.Status -eq 'Running' -and $PSCmdlet.ShouldProcess($Name, 'Stop service; restore after cleanup')) {
                $Restore.Add($Name)
                Stop-Service -Name $Name -Confirm:$false -ErrorAction Stop
                $Service.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped, [timespan]::FromSeconds(30))
            }
        }
    }
    catch {
        if ($Restore.Count) { Start-ServiceSet -ServiceNames $Restore.ToArray() -Confirm:$false }
        throw
    }
    $Restore.ToArray()
}
