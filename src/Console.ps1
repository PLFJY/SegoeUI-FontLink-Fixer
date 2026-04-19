function Write-Headline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ''
    Write-Host ('=== {0} ===' -f $Message)
}

function Write-InfoLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[INFO] {0}' -f $Message)
}

function Write-WarnLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Warning $Message
}

function Write-SuccessLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[OK] {0}' -f $Message) -ForegroundColor Green
}

function Write-ErrorLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[ERROR] {0}' -f $Message) -ForegroundColor Red
}
