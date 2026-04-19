function Get-SupportedProfiles {
    return @(
        [pscustomobject]@{
            Id = 'zh-CN'
            PriorityFonts = @(
                'Microsoft YaHei UI'
                'Microsoft YaHei'
            )
            ManagedValueNames = @(
                'Tahoma'
                'Microsoft Sans Serif'
            )
        }
        [pscustomobject]@{
            Id = 'zh-TW'
            PriorityFonts = @(
                'Microsoft JhengHei UI'
                'Microsoft JhengHei'
            )
            ManagedValueNames = @(
                'Tahoma'
                'Microsoft Sans Serif'
            )
        }
        [pscustomobject]@{
            Id = 'ja-JP'
            PriorityFonts = @(
                'Yu Gothic UI'
                'Yu Gothic'
                'Meiryo UI'
                'Meiryo'
            )
            ManagedValueNames = @(
                'Tahoma'
                'Microsoft Sans Serif'
            )
        }
        [pscustomobject]@{
            Id = 'ko-KR'
            PriorityFonts = @(
                'Malgun Gothic'
            )
            ManagedValueNames = @(
                'Tahoma'
                'Microsoft Sans Serif'
            )
        }
    )
}

function Resolve-Profile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileId
    )

    $profiles = Get-SupportedProfiles
    $match = $profiles | Where-Object { $_.Id -ieq $ProfileId } | Select-Object -First 1

    if ($null -eq $match) {
        $supportedList = ($profiles | Select-Object -ExpandProperty Id) -join ', '
        throw (Format-LocalizedString -Key 'Error.UnsupportedProfile' -Arguments @($ProfileId, $supportedList))
    }

    return $match
}

function Get-EntryFontFamilyName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Entry
    )

    $segments = $Entry -split ','
    if ($segments.Count -ge 2) {
        return $segments[1].Trim()
    }

    return $Entry.Trim()
}

function Get-EntryPriorityRank {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Entry,

        [Parameter(Mandatory = $true)]
        [string[]]$PriorityFonts
    )

    $familyName = Get-EntryFontFamilyName -Entry $Entry

    for ($index = 0; $index -lt $PriorityFonts.Count; $index++) {
        $targetFont = $PriorityFonts[$index]
        if ($familyName.Equals($targetFont, [StringComparison]::OrdinalIgnoreCase)) {
            return $index
        }

        if ($familyName.StartsWith(('{0} ' -f $targetFont), [StringComparison]::OrdinalIgnoreCase)) {
            return $index
        }
    }

    return -1
}

function Get-ReorderedEntriesForProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Entries,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    $decoratedEntries = @()
    for ($index = 0; $index -lt $Entries.Count; $index++) {
        $entry = $Entries[$index]
        $rank = Get-EntryPriorityRank -Entry $entry -PriorityFonts $Profile.PriorityFonts
        $decoratedEntries += [pscustomobject]@{
            Entry = $entry
            Rank = $rank
            OriginalIndex = $index
        }
    }

    $prioritizedEntries = $decoratedEntries |
        Where-Object { $_.Rank -ge 0 } |
        Sort-Object -Property Rank, OriginalIndex

    $unmatchedEntries = $decoratedEntries |
        Where-Object { $_.Rank -lt 0 } |
        Sort-Object -Property OriginalIndex

    $result = @()
    $result += $prioritizedEntries | ForEach-Object { $_.Entry }
    $result += $unmatchedEntries | ForEach-Object { $_.Entry }

    return ,$result
}

function Test-ValueNameManagedByProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ValueName,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    if ($ValueName.StartsWith('Segoe UI', [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    foreach ($managedValueName in @($Profile.ManagedValueNames)) {
        if ($ValueName.Equals($managedValueName, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}
