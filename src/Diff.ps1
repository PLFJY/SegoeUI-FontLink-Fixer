function Get-SystemLinkApplyPlan {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Snapshot,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    $targetValues = @(
        $Snapshot.Values |
            Where-Object { Test-ValueNameManagedByProfile -ValueName $_.Name -Profile $Profile } |
            Sort-Object -Property Name
    )
    $plan = @()

    foreach ($value in $targetValues) {
        if ($value.Kind -ne 'MultiString') {
            throw (Format-LocalizedString -Key 'Error.NonMultiString' -Arguments @($value.Name, $value.Kind))
        }

        $currentEntries = @($value.Data | ForEach-Object { [string]$_ })
        $desiredEntries = $currentEntries

        $desiredEntries = Get-ReorderedEntriesForProfile -Entries $desiredEntries -Profile $Profile

        $hasChanges = -not (Compare-StringArrayExact -Left $currentEntries -Right $desiredEntries)

        $plan += [pscustomobject]@{
            Name = $value.Name
            CurrentEntries = $currentEntries
            DesiredEntries = $desiredEntries
            HasChanges = $hasChanges
        }
    }

    return ,$plan
}

function Show-SegoeApplyPlan {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Plan,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    Write-Headline (Format-LocalizedString -Key 'Header.Preview' -Arguments @($Profile.Id))
    Write-InfoLine (Format-LocalizedString -Key 'Info.ProfileTargetFonts' -Arguments @(($Profile.PriorityFonts -join ', ')))

    $changedItems = @($Plan | Where-Object { $_.HasChanges })

    if ($Plan.Count -eq 0) {
        Write-WarnLine (Get-LocalizedString -Key 'Warn.NoManagedValuesPreview')
        return
    }

    Write-InfoLine (Format-LocalizedString -Key 'Info.ManagedValuesFound' -Arguments @($Plan.Count))

    if ($changedItems.Count -eq 0) {
        Write-SuccessLine (Get-LocalizedString -Key 'Success.NoOrderingChanges')
        return
    }

    foreach ($item in $Plan) {
        Write-Host ''
        Write-Host (Format-LocalizedString -Key 'Preview.Value' -Arguments @($item.Name))
        Write-Host (Format-LocalizedString -Key 'Preview.WillChange' -Arguments @($(if ($item.HasChanges) { Get-LocalizedString -Key 'Preview.Yes' } else { Get-LocalizedString -Key 'Preview.No' })))

        if (-not $item.HasChanges) {
            continue
        }

        Write-Host (Get-LocalizedString -Key 'Preview.Before')
        for ($index = 0; $index -lt $item.CurrentEntries.Count; $index++) {
            Write-Host ('  {0}. {1}' -f ($index + 1), $item.CurrentEntries[$index])
        }

        Write-Host (Get-LocalizedString -Key 'Preview.After')
        for ($index = 0; $index -lt $item.DesiredEntries.Count; $index++) {
            Write-Host ('  {0}. {1}' -f ($index + 1), $item.DesiredEntries[$index])
        }
    }
}
