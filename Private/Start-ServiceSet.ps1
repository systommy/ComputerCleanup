function Start-ServiceSet {
    <#
    .SYNOPSIS
    Restores every listed service, surfacing recovery failures.
    .DESCRIPTION
    Attempts every service even when one fails.
    .PARAMETER ServiceNames
    Services recorded as running before cleanup.
    .EXAMPLE
    Start-ServiceSet -ServiceNames 'ExampleService' -WhatIf
    .OUTPUTS
    None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]] $ServiceNames)
    $Failures = @()
    foreach ($Name in ($ServiceNames | Select-Object -Unique)) {
        if ($PSCmdlet.ShouldProcess($Name, 'Restore previously running service')) {
            try {
                Start-Service -Name $Name -ErrorAction Stop
                (Get-Service -Name $Name -ErrorAction Stop).WaitForStatus([ServiceProcess.ServiceControllerStatus]::Running, [timespan]::FromSeconds(30))
            }
            catch { $Failures += $Name; Write-Warning "Service recovery failed for '$Name'. Check it manually." }
        }
    }
    if ($Failures.Count) { throw "Could not restore services: $($Failures -join ', ')" }
}
