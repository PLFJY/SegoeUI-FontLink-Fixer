function Get-RegistryView {
    if ([Environment]::Is64BitOperatingSystem) {
        return [Microsoft.Win32.RegistryView]::Registry64
    }

    return [Microsoft.Win32.RegistryView]::Default
}

function Get-RegExePath {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        return (Join-Path -Path $env:WINDIR -ChildPath 'Sysnative\reg.exe')
    }

    return (Join-Path -Path $env:WINDIR -ChildPath 'System32\reg.exe')
}

function Open-SystemLinkRegistryKey {
    param(
        [switch]$Writable
    )

    $baseKey = $null
    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine,
            (Get-RegistryView)
        )

        $accessCheck = if ($Writable) { $true } else { $false }
        $registryKey = $baseKey.OpenSubKey($script:SystemLinkSubKeyPath, $accessCheck)

        if ($null -eq $registryKey) {
            throw (Format-LocalizedString -Key 'Error.RegistryKeyNotFound' -Arguments @($script:SystemLinkRegistryPath))
        }

        return $registryKey
    }
    finally {
        if ($null -ne $baseKey) {
            $baseKey.Dispose()
        }
    }
}

function Convert-RegistryValueDataForJson {
    param(
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$Kind
    )

    switch ($Kind) {
        'MultiString' { return @($Data) }
        'Binary' { return @([byte[]]$Data) }
        default { return $Data }
    }
}

function Convert-RegistryValueDataFromSnapshot {
    param(
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Kind
    )

    switch ($Kind) {
        'String' { return [string]$Data }
        'ExpandString' { return [string]$Data }
        'MultiString' { return @($Data | ForEach-Object { [string]$_ }) }
        'Binary' { return [byte[]]@($Data | ForEach-Object { [byte]$_ }) }
        'DWord' { return [int]$Data }
        'QWord' { return [long]$Data }
        default { throw (Format-LocalizedString -Key 'Error.UnsupportedSnapshotKind' -Arguments @($Kind)) }
    }
}

function ConvertTo-RegistryValueKind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind
    )

    return ([Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind], $Kind, $false))
}

function Get-SystemLinkSnapshot {
    $registryKey = Open-SystemLinkRegistryKey

    try {
        $valueNames = $registryKey.GetValueNames() | Sort-Object
        $values = @()

        foreach ($valueName in $valueNames) {
            $kind = $registryKey.GetValueKind($valueName)
            $data = $registryKey.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

            $values += [pscustomobject]@{
                Name = $valueName
                Kind = $kind.ToString()
                Data = Convert-RegistryValueDataForJson -Data $data -Kind $kind
            }
        }

        return [pscustomobject]@{
            RegistryPath = $script:SystemLinkRegistryPath
            NativeRegistryPath = $script:SystemLinkNativeRegistryPath
            ValueCount = $values.Count
            Values = $values
        }
    }
    finally {
        $registryKey.Dispose()
    }
}

function Get-SegoeValuesFromSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Snapshot
    )

    return @(
        $Snapshot.Values |
            Where-Object { $_.Name.StartsWith('Segoe UI', [StringComparison]::OrdinalIgnoreCase) } |
            Sort-Object -Property Name
    )
}

function Compare-StringArrayExact {
    param(
        [AllowNull()]
        [string[]]$Left,

        [AllowNull()]
        [string[]]$Right
    )

    if ($null -eq $Left -and $null -eq $Right) {
        return $true
    }

    if ($null -eq $Left -or $null -eq $Right) {
        return $false
    }

    if ($Left.Count -ne $Right.Count) {
        return $false
    }

    for ($index = 0; $index -lt $Left.Count; $index++) {
        if ($Left[$index] -cne $Right[$index]) {
            return $false
        }
    }

    return $true
}

function Set-SystemLinkValueData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Data
    )

    $registryKey = Open-SystemLinkRegistryKey -Writable

    try {
        $registryKey.SetValue($Name, [string[]]$Data, [Microsoft.Win32.RegistryValueKind]::MultiString)
    }
    finally {
        $registryKey.Dispose()
    }
}

function Restore-SystemLinkSnapshotExact {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Snapshot
    )

    $registryKey = Open-SystemLinkRegistryKey -Writable

    try {
        $currentNames = @($registryKey.GetValueNames())
        $targetNames = @($Snapshot.Values | ForEach-Object { $_.Name })

        foreach ($value in $Snapshot.Values) {
            $kind = ConvertTo-RegistryValueKind -Kind $value.Kind
            $data = Convert-RegistryValueDataFromSnapshot -Data $value.Data -Kind $value.Kind
            $registryKey.SetValue($value.Name, $data, $kind)
        }

        foreach ($valueName in $currentNames) {
            if ($targetNames -notcontains $valueName) {
                $registryKey.DeleteValue($valueName, $false)
            }
        }
    }
    finally {
        $registryKey.Dispose()
    }
}

function Test-SystemLinkSnapshotMatches {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ExpectedSnapshot,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$ActualSnapshot
    )

    $expectedValues = @($ExpectedSnapshot.Values | Sort-Object -Property Name)
    $actualValues = @($ActualSnapshot.Values | Sort-Object -Property Name)

    if ($expectedValues.Count -ne $actualValues.Count) {
        return $false
    }

    for ($index = 0; $index -lt $expectedValues.Count; $index++) {
        $expectedValue = $expectedValues[$index]
        $actualValue = $actualValues[$index]

        if ($expectedValue.Name -cne $actualValue.Name -or $expectedValue.Kind -cne $actualValue.Kind) {
            return $false
        }

        switch ($expectedValue.Kind) {
            'MultiString' {
                if (-not (Compare-StringArrayExact -Left @($expectedValue.Data) -Right @($actualValue.Data))) {
                    return $false
                }
            }
            default {
                if (($expectedValue.Data | ConvertTo-Json -Compress) -cne ($actualValue.Data | ConvertTo-Json -Compress)) {
                    return $false
                }
            }
        }
    }

    return $true
}

function Export-SystemLinkRegFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        throw (Format-LocalizedString -Key 'Error.RegistryExportExists' -Arguments @($DestinationPath))
    }

    $regExePath = Get-RegExePath
    $output = & $regExePath export $script:SystemLinkNativeRegistryPath $DestinationPath /y 2>&1

    if ($LASTEXITCODE -ne 0) {
        $message = if ($output) { ($output | Out-String).Trim() } else { 'Unknown reg.exe export failure.' }
        throw (Format-LocalizedString -Key 'Error.RegistryExportFailed' -Arguments @($message))
    }
}
