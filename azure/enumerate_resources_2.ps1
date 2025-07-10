
# <# header exists before; keep header unchanged; we only need to insert param right after header and before modules>
#>

param(
    [string]$OutputCsv = "AzureResourceSummary-$(Get-Date -Format yyyyMMddHHmmss).csv"
)

# Ensure Az module is installed and imported
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Force
}
Import-Module Az

# Connect to Azure if not already connected
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Connect-AzAccount
}

<#
.SYNOPSIS
    Summarises Azure resources per subscription by type and outputs a CSV.

.DESCRIPTION
    For each accessible subscription, the script counts the total number of
    Azure Resource Manager resources and produces a breakdown by ResourceType.
    All counts are written to a CSV (columns: SubscriptionName, SubscriptionId,
    ResourceType, Count).  A console progress bar shows enumeration progress.

.PARAMETER OutputCsv
    Optional path for the summary CSV.  Defaults to
    AzureResourceSummary-<timestamp>.csv in the current directory.

.EXAMPLE
    PS> ./enumerate_resources_2.ps1
    PS> ./enumerate_resources_2.ps1 -OutputCsv C:\temp\summary.csv
#>

# Prepare collection to hold summary rows
$summary = @()

# Get all subscriptions
$subscriptions = Get-AzSubscription
$totalSubs = $subscriptions.Count
Write-Host "Found $totalSubs subscriptions."

# Enumerate with progress feedback
for ($idx = 0; $idx -lt $totalSubs; $idx++) {
    $sub = $subscriptions[$idx]

    $percent = if ($totalSubs -eq 0) { 0 } else { [math]::Floor((($idx) / $totalSubs) * 100) }
    Write-Progress -Activity "Enumerating Azure resources" -Status "Subscription $($idx+1)/$totalSubs : $($sub.Name)" -PercentComplete $percent

    Write-Host "Processing subscription: $($sub.Name) ($($sub.Id))..."
    Set-AzContext -SubscriptionId $sub.Id | Out-Null

    # Retrieve all resources in the current subscription
    $resources = Get-AzResource -ErrorAction Stop
    $total = $resources.Count
    Write-Host "  Total resources: $total"

    # Add TOTAL row for this subscription
    $summary += [PSCustomObject]@{
        SubscriptionName = $sub.Name
        SubscriptionId   = $sub.Id
        ResourceType     = "TOTAL"
        Count            = $total
    }

    # Group by resource type and add per-type counts
    $resources | Group-Object -Property ResourceType | ForEach-Object {
        $summary += [PSCustomObject]@{
            SubscriptionName = $sub.Name
            SubscriptionId   = $sub.Id
            ResourceType     = $_.Name
            Count            = $_.Count
        }
        Write-Host ("    {0,-50} {1}" -f $_.Name, $_.Count)
    }
    Write-Host ""
}

# Clear the progress bar
Write-Progress -Activity "Enumerating Azure resources" -Completed

# Export summary to CSV
$summary | Sort-Object SubscriptionName, ResourceType |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Summary written to $OutputCsv"