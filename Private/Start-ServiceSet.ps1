<#
    .SYNOPSIS
    Starts a set of services.

    .DESCRIPTION
    Starts each unique non-empty service name provided.

    .PARAMETER ServiceNames
    Service names to start.

    .OUTPUTS
    None
#>
function Start-ServiceSet {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string[]] $ServiceNames
    )

    process {
        if ($ServiceNames.Count -eq 0) {
            return
        }

        $UniqueServiceNames = $ServiceNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
        foreach ($ServiceName in $UniqueServiceNames) {
            try {
                Write-Verbose "Starting service '$ServiceName'..."
                Start-Service -Name $ServiceName -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to start service '$ServiceName': $($_.Exception.Message)"
            }
        }
    }
}
