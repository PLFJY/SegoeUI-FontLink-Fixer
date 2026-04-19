function Show-Usage {
    Write-Host (Get-LocalizedString -Key 'App.Name')
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Usage.Header')
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.Backup'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.Apply'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.RestoreLatest'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.RestoreFile'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.List'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.Status'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.Tui'))
    Write-Host ('  {0}' -f (Get-LocalizedString -Key 'Usage.Command.Help'))
    Write-Host ''
    Write-Host (Get-LocalizedString -Key 'Usage.Profiles')
    Get-SupportedProfiles | ForEach-Object {
        Write-Host ('  {0}  {1}' -f $_.Id, (Get-ProfileDescription -ProfileId $_.Id))
    }
}

function Get-LatestBackupSummaryText {
    $catalog = Get-BackupCatalog
    if ($catalog.Count -eq 0) {
        return (Get-LocalizedString -Key 'Info.LatestBackupSummaryNone')
    }

    $latest = $catalog[0]
    return ('{0} ({1})' -f $latest.BackupId, $latest.BackupDirectory)
}

function Invoke-BackupCommand {
    Write-Headline (Get-LocalizedString -Key 'Header.Backup')
    Write-InfoLine (Format-LocalizedString -Key 'Info.ElevationState' -Arguments @($(if (Test-IsAdministrator) { Get-LocalizedString -Key 'State.Admin' } else { Get-LocalizedString -Key 'State.StandardUser' })))
    Write-InfoLine (Format-LocalizedString -Key 'Info.BackingUpKey' -Arguments @($script:SystemLinkRegistryPath))

    $backup = New-SystemLinkBackup -Reason 'manual-backup'
    Write-SuccessLine (Format-LocalizedString -Key 'Info.BackupCompleted' -Arguments @($backup.BackupDirectory))
    Write-InfoLine (Format-LocalizedString -Key 'Info.RegistryExport' -Arguments @($backup.RegExportPath))
    Write-InfoLine (Format-LocalizedString -Key 'Info.SnapshotJson' -Arguments @($backup.SnapshotPath))
}

function Invoke-ListCommand {
    Write-Headline (Get-LocalizedString -Key 'Header.Profiles')
    foreach ($profile in Get-SupportedProfiles) {
        Write-Host (Format-LocalizedString -Key 'Label.Profile' -Arguments @($profile.Id))
        Write-Host (Format-LocalizedString -Key 'Label.Name' -Arguments @((Get-ProfileDisplayName -ProfileId $profile.Id)))
        Write-Host (Format-LocalizedString -Key 'Label.Description' -Arguments @((Get-ProfileDescription -ProfileId $profile.Id)))
        Write-Host (Format-LocalizedString -Key 'Label.PriorityFonts' -Arguments @(($profile.PriorityFonts -join ', ')))
        Write-Host ''
    }
}

function Invoke-StatusCommand {
    $legacyManagedValueNames = @(
        'Tahoma'
        'Microsoft Sans Serif'
    )

    Write-Headline (Get-LocalizedString -Key 'Header.Status')
    Write-InfoLine (Format-LocalizedString -Key 'Info.ElevationState' -Arguments @($(if (Test-IsAdministrator) { Get-LocalizedString -Key 'State.Admin' } else { Get-LocalizedString -Key 'State.StandardUser' })))
    Write-InfoLine (Format-LocalizedString -Key 'Info.RegistryPath' -Arguments @($script:SystemLinkRegistryPath))
    Write-InfoLine (Format-LocalizedString -Key 'Info.LatestValidBackup' -Arguments @((Get-LatestBackupSummaryText)))

    $snapshot = Get-SystemLinkSnapshot
    $segoeValues = @(
        $snapshot.Values |
            Where-Object {
                $_.Name.StartsWith('Segoe UI', [StringComparison]::OrdinalIgnoreCase) -or
                ($legacyManagedValueNames -contains $_.Name)
            } |
            Sort-Object -Property Name
    )

    Write-InfoLine (Format-LocalizedString -Key 'Info.TotalSystemLinkValues' -Arguments @($snapshot.ValueCount))
    Write-InfoLine (Format-LocalizedString -Key 'Info.ManagedValuesFound' -Arguments @($segoeValues.Count))

    foreach ($value in $segoeValues) {
        Write-Host ''
        Write-Host (Format-LocalizedString -Key 'Preview.Value' -Arguments @($value.Name))
        $entries = @($value.Data)
        for ($index = 0; $index -lt $entries.Count; $index++) {
            Write-Host ('  {0}. {1}' -f ($index + 1), $entries[$index])
        }
    }
}

function Invoke-ApplyCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileId,

        [switch]$DryRun
    )

    $profile = Resolve-Profile -ProfileId $ProfileId
    $snapshot = Get-SystemLinkSnapshot
    $plan = Get-SystemLinkApplyPlan -Snapshot $snapshot -Profile $profile

    if ($plan.Count -eq 0) {
        throw (Get-LocalizedString -Key 'Error.NoManagedValues')
    }

    Show-SegoeApplyPlan -Plan $plan -Profile $profile

    $changedItems = @($plan | Where-Object { $_.HasChanges })
    if ($DryRun) {
        Write-InfoLine (Get-LocalizedString -Key 'Info.DryRunNoWrite')
        return
    }

    if ($changedItems.Count -eq 0) {
        Write-SuccessLine (Get-LocalizedString -Key 'Success.NoChangesNeeded')
        return
    }

    Write-Headline (Get-LocalizedString -Key 'Header.Apply')
    $backup = New-SystemLinkBackup -Reason ('apply-{0}' -f $profile.Id)
    Write-InfoLine (Format-LocalizedString -Key 'Info.BackupLocation' -Arguments @($backup.BackupDirectory))

    foreach ($item in $changedItems) {
        Write-InfoLine (Format-LocalizedString -Key 'Info.UpdatingValue' -Arguments @($item.Name))
        Set-SystemLinkValueData -Name $item.Name -Data $item.DesiredEntries
    }

    $verificationSnapshot = Get-SystemLinkSnapshot
    $verifiedValues = @(
        $verificationSnapshot.Values |
            Where-Object { Test-ValueNameManagedByProfile -ValueName $_.Name -Profile $profile }
    )
    $verificationFailed = $false

    foreach ($item in $changedItems) {
        $actualValue = $verifiedValues | Where-Object { $_.Name -ceq $item.Name } | Select-Object -First 1
        if ($null -eq $actualValue) {
            Write-ErrorLine (Format-LocalizedString -Key 'Error.ApplyVerificationMissing' -Arguments @($item.Name))
            $verificationFailed = $true
            continue
        }

        $actualEntries = @($actualValue.Data | ForEach-Object { [string]$_ })
        if (-not (Compare-StringArrayExact -Left $actualEntries -Right $item.DesiredEntries)) {
            Write-ErrorLine (Format-LocalizedString -Key 'Error.ApplyVerificationMismatch' -Arguments @($item.Name))
            $verificationFailed = $true
        }
    }

    if ($verificationFailed) {
        throw (Format-LocalizedString -Key 'Error.ApplyVerificationFailed' -Arguments @($backup.BackupDirectory))
    }

    Write-SuccessLine (Format-LocalizedString -Key 'Success.ApplyVerified' -Arguments @($changedItems.Count))
    Write-WarnLine (Get-LocalizedString -Key 'Warn.LogoffRequired')
}

function Invoke-RestoreCommand {
    param(
        [switch]$Latest,

        [string]$BackupPath
    )

    Write-Headline (Get-LocalizedString -Key 'Header.Restore')
    $selectedBackup = Resolve-BackupSelection -Latest:$Latest -BackupPath $BackupPath

    Write-InfoLine (Format-LocalizedString -Key 'Info.SelectedBackup' -Arguments @($selectedBackup.BackupDirectory))
    Write-InfoLine (Format-LocalizedString -Key 'Info.CreatedAtUtc' -Arguments @($selectedBackup.Manifest.CreatedAtUtc))
    Write-InfoLine (Format-LocalizedString -Key 'Info.ContainsValues' -Arguments @($selectedBackup.Manifest.ValueCount))
    Write-InfoLine (Get-LocalizedString -Key 'Info.ValueNamesToRestore')
    foreach ($valueName in $selectedBackup.Manifest.ValueNames) {
        Write-Host ('  - {0}' -f $valueName)
    }

    $safetyBackup = New-SystemLinkBackup -Reason ('pre-restore-{0}' -f $selectedBackup.Manifest.BackupId)
    Write-InfoLine (Format-LocalizedString -Key 'Info.CurrentStateSafetyBackup' -Arguments @($safetyBackup.BackupDirectory))

    Restore-SystemLinkSnapshotExact -Snapshot $selectedBackup.Snapshot

    $verificationSnapshot = Get-SystemLinkSnapshot
    $isVerified = Test-SystemLinkSnapshotMatches -ExpectedSnapshot $selectedBackup.Snapshot -ActualSnapshot $verificationSnapshot

    if (-not $isVerified) {
        throw (Format-LocalizedString -Key 'Error.RestoreVerificationFailed' -Arguments @($safetyBackup.BackupDirectory))
    }

    Write-SuccessLine (Format-LocalizedString -Key 'Success.RestoreVerified' -Arguments @($selectedBackup.Manifest.BackupId))
    Write-WarnLine (Get-LocalizedString -Key 'Warn.LogoffRequired')
}
