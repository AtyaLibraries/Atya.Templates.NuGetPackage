param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,

    [Parameter(Mandatory = $true)]
    [string]$RepoName
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

gh api -X PATCH "repos/$repository" `
    -f default_branch=development `
    -F allow_squash_merge=true `
    -F allow_merge_commit=true `
    -F allow_rebase_merge=false | Out-Null

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Confirm org-level setup covers this repository:"
Write-Host "     atya-managed=true, standard labels, rulesets, and NUGET_API_KEY access."
Write-Host "  2. Confirm CI is green on development."
Write-Host "  3. Open and merge a PR from development to master."
Write-Host "  4. The merge triggers the first stable publish, or run Publish NuGet"
Write-Host "     manually with an explicit stable version."
