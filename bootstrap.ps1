param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [string]$NugetApiKey
)

$ErrorActionPreference = "Stop"
$repository = "$RepoOwner/$RepoName"

try {
    gh auth status | Out-Null
}
catch {
    throw "GitHub CLI authentication is required. Run 'gh auth login' and rerun this script."
}

Write-Host "Configuring $repository..." -ForegroundColor Cyan

gh repo edit $repository --default-branch development

$branchProtection = @{
    required_status_checks = @{
        strict = $true
        contexts = @(
            "build-ubuntu-latest",
            "build-windows-latest"
        )
    }
    enforce_admins = $false
    required_pull_request_reviews = @{
        required_approving_review_count = 1
    }
    restrictions = $null
    required_linear_history = $true
    allow_force_pushes = $false
    allow_deletions = $false
}

foreach ($branch in @("master", "development")) {
    Write-Host "Applying branch protection to $branch..." -ForegroundColor Yellow
    $branchProtection |
        ConvertTo-Json -Depth 10 |
        gh api -X PUT "repos/$repository/branches/$branch/protection" --input -
}

if (-not [string]::IsNullOrWhiteSpace($NugetApiKey)) {
    Write-Host "Setting NUGET_API_KEY secret..." -ForegroundColor Yellow
    $NugetApiKey | gh secret set NUGET_API_KEY --repo $repository
}

$labels = @(
    @{ Name = "enhancement"; Color = "a2eeef"; Description = "New feature or request" },
    @{ Name = "bug"; Color = "d73a4a"; Description = "Something is not working" },
    @{ Name = "chore"; Color = "ededed"; Description = "Internal maintenance" },
    @{ Name = "dependencies"; Color = "0366d6"; Description = "Dependency updates" },
    @{ Name = "breaking"; Color = "b60205"; Description = "Breaking change" }
)

foreach ($label in $labels) {
    gh label create $label.Name `
        --repo $repository `
        --color $label.Color `
        --description $label.Description `
        --force
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Confirm CI is green on development."
Write-Host "  2. Open and merge a PR from development to master."
Write-Host "  3. Tag v1.0.0 to trigger the first stable publish:"
Write-Host "     git tag v1.0.0"
Write-Host "     git push origin v1.0.0"
