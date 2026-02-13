<#
    .SYNOPSIS
    Verifies if current user context has Administrator privileges.

    .DESCRIPTION
    Checks whether the current PowerShell session is running with elevated
    (Administrator) privileges. Throws a terminating error if not elevated.

    .EXAMPLE
    Assert-RunAsAdministrator
    Verifies the session is elevated; throws if not.

    .OUTPUTS
    None. Throws a terminating error if not running as Administrator.

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://systom.dev
#>
function Assert-RunAsAdministrator {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    process {
        $CurrentUser = New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )

        if ($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
            Write-Verbose 'Script is running with Administrator privileges.'
        }
        else {
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.UnauthorizedAccessException]::new('Script/function is NOT running with Administrator privileges. Please re-run as Administrator.'),
                'NotElevated',
                [System.Management.Automation.ErrorCategory]::PermissionDenied,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
}
