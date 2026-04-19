function Ensure-BackupRoot {
    if (-not (Test-Path -LiteralPath $script:BackupRoot)) {
        New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    }
}

function New-BackupId {
    return (Get-Date).ToString('yyyyMMdd-HHmmssfff')
}

function Get-BackupManifestPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory
    )

    return (Join-Path -Path $BackupDirectory -ChildPath 'manifest.json')
}

function Get-BackupMarkerPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory
    )

    return (Join-Path -Path $BackupDirectory -ChildPath 'backup.incomplete.txt')
}

function Write-IncompleteBackupMarker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    $markerPath = Get-BackupMarkerPath -BackupDirectory $BackupDirectory
    Set-Content -LiteralPath $markerPath -Value $Reason -Encoding UTF8
}

function New-SystemLinkBackup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    Ensure-BackupRoot

    $backupId = New-BackupId
    $backupDirectory = Join-Path -Path $script:BackupRoot -ChildPath $backupId

    if (Test-Path -LiteralPath $backupDirectory) {
        throw (Format-LocalizedString -Key 'Error.BackupDirectoryExists' -Arguments @($backupDirectory))
    }

    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    Write-IncompleteBackupMarker -BackupDirectory $backupDirectory -Reason 'Backup started but did not finish.'

    try {
        $createdAt = Get-Date
        $snapshot = Get-SystemLinkSnapshot
        $snapshotPath = Join-Path -Path $backupDirectory -ChildPath 'SystemLink.snapshot.json'
        $regExportPath = Join-Path -Path $backupDirectory -ChildPath 'SystemLink.reg'

        $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
        Export-SystemLinkRegFile -DestinationPath $regExportPath

        $manifest = [ordered]@{
            SchemaVersion = $script:BackupSchemaVersion
            BackupId = $backupId
            Reason = $Reason
            CreatedAtUtc = $createdAt.ToUniversalTime().ToString('o')
            CreatedAtLocal = $createdAt.ToString('yyyy-MM-dd HH:mm:ss zzz')
            RegistryPath = $script:SystemLinkRegistryPath
            NativeRegistryPath = $script:SystemLinkNativeRegistryPath
            SnapshotFile = 'SystemLink.snapshot.json'
            SnapshotSha256 = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
            RegExportFile = 'SystemLink.reg'
            RegExportSha256 = (Get-FileHash -LiteralPath $regExportPath -Algorithm SHA256).Hash
            ValueCount = $snapshot.ValueCount
            SegoeValueCount = @((Get-SegoeValuesFromSnapshot -Snapshot $snapshot)).Count
            ValueNames = @($snapshot.Values | ForEach-Object { $_.Name })
            IsComplete = $true
        }

        $manifestPath = Get-BackupManifestPath -BackupDirectory $backupDirectory
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        Remove-Item -LiteralPath (Get-BackupMarkerPath -BackupDirectory $backupDirectory) -Force

        return (Test-BackupManifestValid -BackupDirectory $backupDirectory)
    }
    catch {
        Write-IncompleteBackupMarker -BackupDirectory $backupDirectory -Reason $_.Exception.Message
        throw
    }
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Test-BackupManifestValid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory
    )

    $manifestPath = Get-BackupManifestPath -BackupDirectory $BackupDirectory

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw (Format-LocalizedString -Key 'Error.BackupManifestNotFound' -Arguments @($manifestPath))
    }

    if (Test-Path -LiteralPath (Get-BackupMarkerPath -BackupDirectory $BackupDirectory)) {
        throw (Format-LocalizedString -Key 'Error.BackupIncompleteDirectory' -Arguments @($BackupDirectory))
    }

    $manifest = Read-JsonFile -Path $manifestPath

    if (-not $manifest.IsComplete) {
        throw (Format-LocalizedString -Key 'Error.BackupManifestIncomplete' -Arguments @($manifestPath))
    }

    if ($manifest.SchemaVersion -ne $script:BackupSchemaVersion) {
        throw (Format-LocalizedString -Key 'Error.UnsupportedBackupSchema' -Arguments @($manifest.SchemaVersion, $manifestPath))
    }

    if ($manifest.RegistryPath -ne $script:SystemLinkRegistryPath -or $manifest.NativeRegistryPath -ne $script:SystemLinkNativeRegistryPath) {
        throw (Format-LocalizedString -Key 'Error.BackupWrongRegistryKey' -Arguments @($manifestPath))
    }

    $snapshotPath = Join-Path -Path $BackupDirectory -ChildPath $manifest.SnapshotFile
    $regExportPath = Join-Path -Path $BackupDirectory -ChildPath $manifest.RegExportFile

    foreach ($requiredPath in @($snapshotPath, $regExportPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw (Format-LocalizedString -Key 'Error.BackupFileMissing' -Arguments @($requiredPath))
        }
    }

    $actualSnapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
    $actualRegExportHash = (Get-FileHash -LiteralPath $regExportPath -Algorithm SHA256).Hash

    if ($actualSnapshotHash -ne $manifest.SnapshotSha256) {
        throw (Format-LocalizedString -Key 'Error.BackupSnapshotHashMismatch' -Arguments @($BackupDirectory))
    }

    if ($actualRegExportHash -ne $manifest.RegExportSha256) {
        throw (Format-LocalizedString -Key 'Error.BackupRegHashMismatch' -Arguments @($BackupDirectory))
    }

    $snapshot = Read-JsonFile -Path $snapshotPath
    if ($snapshot.NativeRegistryPath -ne $script:SystemLinkNativeRegistryPath) {
        throw (Format-LocalizedString -Key 'Error.BackupSnapshotWrongPath' -Arguments @($snapshot.NativeRegistryPath))
    }

    if ($snapshot.ValueCount -ne $manifest.ValueCount) {
        throw (Format-LocalizedString -Key 'Error.BackupManifestIncomplete' -Arguments @($manifestPath))
    }

    return [pscustomobject]@{
        BackupDirectory = $BackupDirectory
        ManifestPath = $manifestPath
        Manifest = $manifest
        SnapshotPath = $snapshotPath
        Snapshot = $snapshot
        RegExportPath = $regExportPath
    }
}

function Get-BackupCatalog {
    Ensure-BackupRoot

    $directories = Get-ChildItem -LiteralPath $script:BackupRoot -Directory | Sort-Object -Property Name -Descending
    $catalog = @()

    foreach ($directory in $directories) {
        try {
            $validatedBackup = Test-BackupManifestValid -BackupDirectory $directory.FullName
            $catalog += [pscustomobject]@{
                BackupId = $validatedBackup.Manifest.BackupId
                BackupDirectory = $validatedBackup.BackupDirectory
                CreatedAtUtc = $validatedBackup.Manifest.CreatedAtUtc
                Reason = $validatedBackup.Manifest.Reason
                ValueCount = $validatedBackup.Manifest.ValueCount
            }
        }
        catch {
        }
    }

    return ,$catalog
}

function Resolve-BackupSelection {
    param(
        [switch]$Latest,

        [string]$BackupPath
    )

    if ($Latest -and $BackupPath) {
        throw (Get-LocalizedString -Key 'Error.RestoreLatestOrFile')
    }

    if (-not $Latest -and -not $BackupPath) {
        throw (Get-LocalizedString -Key 'Error.RestoreSelectorRequired')
    }

    if ($Latest) {
        $catalog = Get-BackupCatalog
        if ($catalog.Count -eq 0) {
            throw (Format-LocalizedString -Key 'Error.NoValidBackups' -Arguments @($script:BackupRoot))
        }

        return (Test-BackupManifestValid -BackupDirectory $catalog[0].BackupDirectory)
    }

    $resolvedPath = Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop
    $candidatePath = $resolvedPath.Path

    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
        $candidatePath = Split-Path -Path $candidatePath -Parent
    }

    return (Test-BackupManifestValid -BackupDirectory $candidatePath)
}
