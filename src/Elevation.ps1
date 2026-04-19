function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PowerShellExecutablePath {
    if (-not [Environment]::Is64BitOperatingSystem) {
        return (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    if ([Environment]::Is64BitProcess) {
        return (Join-Path -Path $env:WINDIR -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe')
    }

    return (Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\WindowsPowerShell\v1.0\powershell.exe')
}

function ConvertTo-Base64Unicode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Text))
}

function New-ElevationBootstrapCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $payloadObject = [ordered]@{
        ScriptPath = $ScriptPath
        Arguments = @($Arguments)
    }

    $payloadJson = $payloadObject | ConvertTo-Json -Depth 4 -Compress
    $encodedPayload = ConvertTo-Base64Unicode -Text $payloadJson

    $bootstrap = @"
`$payloadJson = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encodedPayload'))
`$payload = ConvertFrom-Json -InputObject `$payloadJson
`$scriptPath = [string]`$payload.ScriptPath
`$argumentList = @()
foreach (`$argumentItem in @(`$payload.Arguments)) {
    `$argumentList += [string]`$argumentItem
}
& `$scriptPath @argumentList
exit `$LASTEXITCODE
"@

    return (ConvertTo-Base64Unicode -Text $bootstrap)
}

function Ensure-ElevatedSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$OriginalArguments
    )

    if (Test-IsAdministrator) {
        Write-InfoLine (Get-LocalizedString -Key 'State.RunningAsAdmin')
        return
    }

    Write-WarnLine (Get-LocalizedString -Key 'Elevation.NotAdmin')
    Write-InfoLine (Get-LocalizedString -Key 'Elevation.Relaunching')

    $powerShellPath = Get-PowerShellExecutablePath
    $bootstrapCommand = New-ElevationBootstrapCommand -ScriptPath $ScriptPath -Arguments $OriginalArguments
    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-EncodedCommand'
        $bootstrapCommand
    )

    $process = Start-Process -FilePath $powerShellPath `
        -ArgumentList $argumentList `
        -Verb RunAs `
        -Wait `
        -PassThru

    if ($null -eq $process) {
        throw (Get-LocalizedString -Key 'Error.StartElevated')
    }

    exit $process.ExitCode
}
