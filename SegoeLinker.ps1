Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OriginalArguments = @($args)
$script:EntrypointPath = $PSCommandPath

. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Config.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Localization.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Settings.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Console.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Elevation.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Profiles.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Registry.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Diff.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Backup.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Commands.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Tui.ps1')

function Parse-CommandLine {
    param(
        [string[]]$Arguments
    )

    if ($null -eq $Arguments) {
        $Arguments = @()
    }

    $languageId = $null
    $normalizedArguments = New-Object System.Collections.Generic.List[string]
    for ($argumentIndex = 0; $argumentIndex -lt $Arguments.Count; $argumentIndex++) {
        if ($Arguments[$argumentIndex] -eq '--lang') {
            $argumentIndex++
            if ($argumentIndex -ge $Arguments.Count) {
                throw (Get-LocalizedString -Key 'Error.LanguageIdRequired')
            }

            $languageId = $Arguments[$argumentIndex]
            continue
        }

        [void]$normalizedArguments.Add($Arguments[$argumentIndex])
    }

    $Arguments = $normalizedArguments.ToArray()

    if ($Arguments.Count -eq 0) {
        return [pscustomobject]@{
            Command = 'tui'
            ProfileId = $null
            DryRun = $false
            RestoreLatest = $false
            RestoreFile = $null
            LanguageId = $languageId
        }
    }

    $index = 0
    while ($index -lt $Arguments.Count) {
        switch ($Arguments[$index]) {
            '--help' { return [pscustomobject]@{ Command = 'help'; ProfileId = $null; DryRun = $false; RestoreLatest = $false; RestoreFile = $null; LanguageId = $languageId } }
            '-h' { return [pscustomobject]@{ Command = 'help'; ProfileId = $null; DryRun = $false; RestoreLatest = $false; RestoreFile = $null; LanguageId = $languageId } }
            '/?' { return [pscustomobject]@{ Command = 'help'; ProfileId = $null; DryRun = $false; RestoreLatest = $false; RestoreFile = $null; LanguageId = $languageId } }
            default { break }
        }

        break
    }

    if ($index -ge $Arguments.Count) {
        return [pscustomobject]@{
            Command = 'tui'
            ProfileId = $null
            DryRun = $false
            RestoreLatest = $false
            RestoreFile = $null
            LanguageId = $languageId
        }
    }

    $command = $Arguments[$index].ToLowerInvariant()
    $remaining = @()
    if ($Arguments.Count -gt ($index + 1)) {
        $remaining = $Arguments[($index + 1)..($Arguments.Count - 1)]
    }

    $result = [ordered]@{
        Command = $command
        ProfileId = $null
        DryRun = $false
        RestoreLatest = $false
        RestoreFile = $null
        LanguageId = $languageId
    }

    switch ($command) {
        'apply' {
            if ($remaining.Count -eq 0) {
                throw (Get-LocalizedString -Key 'Error.ApplyMissingProfile')
            }

            $result.ProfileId = $remaining[0]

            for ($index = 1; $index -lt $remaining.Count; $index++) {
                switch ($remaining[$index]) {
                    '--dry-run' { $result.DryRun = $true }
                    default { throw (Format-LocalizedString -Key 'Error.UnknownApplyOption' -Arguments @($remaining[$index])) }
                }
            }
        }
        'restore' {
            for ($index = 0; $index -lt $remaining.Count; $index++) {
                switch ($remaining[$index]) {
                    '--latest' { $result.RestoreLatest = $true }
                    '--file' {
                        $index++
                        if ($index -ge $remaining.Count) {
                            throw (Get-LocalizedString -Key 'Error.RestoreMissingPath')
                        }

                        $result.RestoreFile = $remaining[$index]
                    }
                    default { throw (Format-LocalizedString -Key 'Error.UnknownRestoreOption' -Arguments @($remaining[$index])) }
                }
            }
        }
        'backup' { }
        'list' { }
        'status' { }
        'tui' { }
        'help' { }
        default { throw (Format-LocalizedString -Key 'Error.UnknownCommand' -Arguments @($Arguments[$index])) }
    }

    return [pscustomobject]$result
}

try {
    Initialize-UiLanguagePreference
    $parsed = Parse-CommandLine -Arguments $script:OriginalArguments

    if ($parsed.LanguageId) {
        Set-UiLanguage -LanguageId $parsed.LanguageId | Out-Null
        Save-UiLanguagePreference -LanguageId (Get-UiLanguage)
    }

    $requiresElevation = $false
    switch ($parsed.Command) {
        'apply' { if (-not $parsed.DryRun) { $requiresElevation = $true } }
        'restore' { $requiresElevation = $true }
    }

    if ($requiresElevation) {
        Ensure-ElevatedSession -ScriptPath $PSCommandPath -OriginalArguments $script:OriginalArguments
    }
    elseif (Test-IsAdministrator) {
        Write-InfoLine (Get-LocalizedString -Key 'State.RunningAsAdmin')
    }
    else {
        Write-InfoLine (Get-LocalizedString -Key 'State.RunningWithoutAdmin')
    }

    switch ($parsed.Command) {
        'backup' { Invoke-BackupCommand }
        'apply' { Invoke-ApplyCommand -ProfileId $parsed.ProfileId -DryRun:$parsed.DryRun }
        'restore' { Invoke-RestoreCommand -Latest:$parsed.RestoreLatest -BackupPath $parsed.RestoreFile }
        'list' { Invoke-ListCommand }
        'status' { Invoke-StatusCommand }
        'tui' { Invoke-Tui -InitialLanguage $parsed.LanguageId }
        default { Show-Usage }
    }
}
catch {
    Write-ErrorLine $_.Exception.Message
    exit 1
}
