function Get-UiSettingsPath {
    return $script:UiSettingsPath
}

function Read-UiSettings {
    $settingsPath = Get-UiSettingsPath
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        return $null
    }

    try {
        return (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Save-UiLanguagePreference {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LanguageId
    )

    $settings = [ordered]@{
        SchemaVersion = 1
        LanguageId = $LanguageId
        SavedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Get-UiSettingsPath) -Encoding UTF8
}

function Initialize-UiLanguagePreference {
    $settings = Read-UiSettings
    if ($null -eq $settings) {
        return
    }

    if ([string]::IsNullOrWhiteSpace([string]$settings.LanguageId)) {
        return
    }

    try {
        Set-UiLanguage -LanguageId ([string]$settings.LanguageId) | Out-Null
    }
    catch {
    }
}
