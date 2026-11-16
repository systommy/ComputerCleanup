<#
    .SYNOPSIS
    Stops processes gracefully before forcing termination.

    .DESCRIPTION
    For each process name, attempts CloseMainWindow(), waits briefly, then
    force-stops remaining processes if they are still running.

    .PARAMETER ProcessNames
    Process names to close.

    .PARAMETER TimeoutSeconds
    Number of seconds to wait after graceful close request.

    .OUTPUTS
    None
#>
function Stop-ProcessGracefully {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string[]] $ProcessNames,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int] $TimeoutSeconds = 5
    )

    process {
        $UniqueProcessNames = $ProcessNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

        foreach ($ProcessName in $UniqueProcessNames) {
            $Processes = @(Get-Process -ProcessName $ProcessName -ErrorAction SilentlyContinue)
            if ($Processes.Count -eq 0) {
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($ProcessName, 'Close windows then force termination if necessary')) { continue }

            Write-Verbose "Trying graceful shutdown for process '$ProcessName'..."

            foreach ($Process in $Processes) {
                try {
                    if (-not $Process.HasExited) {
                        [void] $Process.CloseMainWindow()
                    }
                }
                catch {
                    Write-Verbose "CloseMainWindow failed for '$ProcessName' (PID $($Process.Id)): $($_.Exception.Message)"
                }
            }

            try {
                Wait-Process -Id $Processes.Id -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "Wait-Process timeout or error for '$ProcessName': $($_.Exception.Message)"
            }

            $RemainingProcesses = @(Get-Process -Id $Processes.Id -ErrorAction SilentlyContinue)
            if ($RemainingProcesses.Count -gt 0) {
                Write-Verbose "Forcing shutdown for process '$ProcessName'..."
                foreach ($RemainingProcess in $RemainingProcesses) {
                    try {
                        Stop-Process -Id $RemainingProcess.Id -Force -Confirm:$false -ErrorAction Stop
                    }
                    catch {
                        throw "Stop-Process failed for '$ProcessName' (PID $($RemainingProcess.Id)): $($_.Exception.Message)"
                    }
                }
            }
        }
    }
}
