$script:SystemLinkRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$script:SystemLinkNativeRegistryPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$script:SystemLinkSubKeyPath = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
$script:BackupSchemaVersion = 1
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:BackupRoot = Join-Path -Path $script:ProjectRoot -ChildPath 'backups'
$script:UiSettingsPath = Join-Path -Path $script:ProjectRoot -ChildPath '.segoelinker.user.json'
$script:DefaultUiLanguage = 'en-US'
