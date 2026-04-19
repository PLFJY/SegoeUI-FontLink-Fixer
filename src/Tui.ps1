function Clear-TuiScreen {
    try {
        Clear-Host
    }
    catch {
    }
}

function Read-TuiInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    return (Read-Host $Prompt).Trim()
}

function Read-TuiKey {
    param(
        [string[]]$AllowedKeys = @(),

        [switch]$AllowEnter,

        [switch]$AllowEscape
    )

    $normalizedAllowedKeys = @($AllowedKeys | ForEach-Object { $_.ToUpperInvariant() })

    $canUseImmediateKeyRead = $true
    try {
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
            $canUseImmediateKeyRead = $false
        }
    }
    catch {
    }

    if ($canUseImmediateKeyRead) {
        while ($true) {
            try {
                $keyInfo = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                $keyToken = $null

                if ($AllowEscape -and $keyInfo.VirtualKeyCode -eq 27) {
                    return 'ESC'
                }

                if ($AllowEnter -and $keyInfo.VirtualKeyCode -eq 13) {
                    return 'ENTER'
                }

                if ($keyInfo.Character -ne [char]0) {
                    $keyToken = ([string]$keyInfo.Character).ToUpperInvariant()
                }

                if ([string]::IsNullOrWhiteSpace($keyToken)) {
                    continue
                }

                if ($normalizedAllowedKeys.Count -eq 0 -or $normalizedAllowedKeys -contains $keyToken) {
                    return $keyToken
                }
            }
            catch {
                break
            }
        }
    }

    while ($true) {
        $response = Read-Host
        if ($AllowEnter -and [string]::IsNullOrEmpty($response)) {
            return 'ENTER'
        }

        if ([string]::IsNullOrEmpty($response)) {
            continue
        }

        $keyToken = $response.Substring(0, 1).ToUpperInvariant()
        if ($normalizedAllowedKeys.Count -eq 0 -or $normalizedAllowedKeys -contains $keyToken) {
            return $keyToken
        }
    }
}

function Wait-TuiContinue {
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Tui.PressAnyKey')
    [void](Read-TuiKey)
}

function Invoke-ScriptCommandFromTui {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $powerShellPath = Get-PowerShellExecutablePath
    & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $script:EntrypointPath @Arguments

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorLine (Format-LocalizedString -Key 'Error.ChildCommandFailed' -Arguments @($LASTEXITCODE))
    }
}

function Show-TuiHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Clear-TuiScreen
    Write-Headline $Title
    Write-InfoLine (Format-LocalizedString -Key 'Info.CurrentLanguage' -Arguments @((Get-LocalizedLanguageName -LanguageId (Get-UiLanguage))))
    Write-InfoLine (Format-LocalizedString -Key 'Info.ElevationState' -Arguments @($(if (Test-IsAdministrator) { Get-LocalizedString -Key 'State.Admin' } else { Get-LocalizedString -Key 'State.StandardUser' })))
    Write-InfoLine (Format-LocalizedString -Key 'Info.LatestValidBackup' -Arguments @((Get-LatestBackupSummaryText)))
    Write-Host ''
}

function Show-TuiMainMenu {
    Show-TuiHeader -Title (Get-LocalizedString -Key 'App.Name')
    Write-Host (Get-LocalizedString -Key 'Tui.Welcome')
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Backup')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.PreviewApply')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Apply')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.RestoreLatest')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.RestorePath')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Status')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.ListProfiles')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.SwitchLanguage')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Help')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Exit')
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Tui.ActionHint')
}

function Select-ProfileFromTui {
    $profiles = @(Get-SupportedProfiles)

    while ($true) {
        Show-TuiHeader -Title (Get-LocalizedString -Key 'Tui.Header.SelectProfile')

        for ($index = 0; $index -lt $profiles.Count; $index++) {
            $profile = $profiles[$index]
            Write-Host ('{0}. {1}  {2}' -f ($index + 1), $profile.Id, (Get-ProfileDisplayName -ProfileId $profile.Id))
            Write-Host ('   {0}' -f (Get-ProfileDescription -ProfileId $profile.Id))
        }

        Write-Host ''
        Write-Host (Get-LocalizedString -Key 'Tui.Option.Back')
        Write-Host ''
        Write-Host (Get-LocalizedString -Key 'Tui.ActionHint')

        $allowedKeys = @('0')
        for ($index = 0; $index -lt $profiles.Count; $index++) {
            $allowedKeys += [string]($index + 1)
        }

        $selection = Read-TuiKey -AllowedKeys $allowedKeys
        if ($selection -eq '0') {
            return $null
        }

        return $profiles[[int]$selection - 1]
    }
}

function Show-LanguageSelectionMenu {
    $languages = @(Get-SupportedLanguages)

    while ($true) {
        Show-TuiHeader -Title (Get-LocalizedString -Key 'Tui.Header.SelectLanguage')

        for ($index = 0; $index -lt $languages.Count; $index++) {
            $language = $languages[$index]
            Write-Host ('{0}. {1}  {2}' -f ($index + 1), $language.Id, $language.NativeName)
        }

        Write-Host ''
        Write-Host (Get-LocalizedString -Key 'Tui.Option.Back')
        Write-Host ''
        Write-Host (Get-LocalizedString -Key 'Tui.ActionHint')

        $allowedKeys = @('0')
        for ($index = 0; $index -lt $languages.Count; $index++) {
            $allowedKeys += [string]($index + 1)
        }

        $selection = Read-TuiKey -AllowedKeys $allowedKeys
        if ($selection -eq '0') {
            return
        }

        $language = $languages[[int]$selection - 1]
        Set-UiLanguage -LanguageId $language.Id | Out-Null
        Save-UiLanguagePreference -LanguageId $language.Id
        Write-SuccessLine (Format-LocalizedString -Key 'Info.LanguageSwitched' -Arguments @($language.NativeName))
        Wait-TuiContinue
        return
    }
}

function Confirm-TuiAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Show-TuiHeader -Title (Get-LocalizedString -Key 'Tui.Header.Confirm')
    Write-WarnLine $Message
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Confirm')
    Write-Host (Get-LocalizedString -Key 'Tui.Option.Cancel')
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Tui.ActionHint')

    return ((Read-TuiKey -AllowedKeys @('1', '0')) -eq '1')
}

function Invoke-TuiProfileAction {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Preview', 'Apply')]
        [string]$Mode
    )

    $profile = Select-ProfileFromTui
    if ($null -eq $profile) {
        return
    }

    if ($Mode -eq 'Preview') {
        Clear-TuiScreen
        Invoke-ApplyCommand -ProfileId $profile.Id -DryRun
        Wait-TuiContinue
        return
    }

    if (-not (Confirm-TuiAction -Message (Get-LocalizedString -Key 'Tui.Prompt.ConfirmApply'))) {
        return
    }

    Invoke-ScriptCommandFromTui -Arguments @('apply', $profile.Id, '--lang', (Get-UiLanguage))
    Wait-TuiContinue
}

function Invoke-TuiRestoreLatest {
    if (-not (Confirm-TuiAction -Message (Get-LocalizedString -Key 'Tui.Prompt.ConfirmRestoreLatest'))) {
        return
    }

    Invoke-ScriptCommandFromTui -Arguments @('restore', '--latest', '--lang', (Get-UiLanguage))
    Wait-TuiContinue
}

function Invoke-TuiRestoreFromPath {
    Show-TuiHeader -Title (Get-LocalizedString -Key 'Header.Restore')
    $backupPath = Read-TuiInput -Prompt (Get-LocalizedString -Key 'Tui.Prompt.BackupPath')
    if ([string]::IsNullOrWhiteSpace($backupPath)) {
        return
    }

    if (-not (Confirm-TuiAction -Message (Get-LocalizedString -Key 'Tui.Prompt.ConfirmRestorePath'))) {
        return
    }

    Invoke-ScriptCommandFromTui -Arguments @('restore', '--file', $backupPath, '--lang', (Get-UiLanguage))
    Wait-TuiContinue
}

function Invoke-Tui {
    param(
        [string]$InitialLanguage
    )

    if ($InitialLanguage) {
        Set-UiLanguage -LanguageId $InitialLanguage | Out-Null
    }

    while ($true) {
        try {
            Show-TuiMainMenu
            $selection = Read-TuiKey -AllowedKeys @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')

            switch ($selection) {
                '1' {
                    Clear-TuiScreen
                    Invoke-BackupCommand
                    Wait-TuiContinue
                }
                '2' { Invoke-TuiProfileAction -Mode 'Preview' }
                '3' { Invoke-TuiProfileAction -Mode 'Apply' }
                '4' { Invoke-TuiRestoreLatest }
                '5' { Invoke-TuiRestoreFromPath }
                '6' {
                    Clear-TuiScreen
                    Invoke-StatusCommand
                    Wait-TuiContinue
                }
                '7' {
                    Clear-TuiScreen
                    Invoke-ListCommand
                    Wait-TuiContinue
                }
                '8' { Show-LanguageSelectionMenu }
                '9' {
                    Clear-TuiScreen
                    Show-Usage
                    Wait-TuiContinue
                }
                '0' { return }
            }
        }
        catch {
            Write-ErrorLine $_.Exception.Message
            Wait-TuiContinue
        }
    }
}
