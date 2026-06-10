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

$rulesetName = "Protected branches"
$ruleset = @{
    name = $rulesetName
    target = "branch"
    enforcement = "active"
    bypass_actors = @()
    conditions = @{
        ref_name = @{
            include = @(
                "refs/heads/master",
                "refs/heads/development"
            )
            exclude = @()
        }
    }
    rules = @(
        @{ type = "deletion" },
        @{ type = "non_fast_forward" },
        @{ type = "required_linear_history" },
        @{ type = "required_signatures" },
        @{
            type = "pull_request"
            parameters = @{
                allowed_merge_methods = @("squash", "rebase")
                dismiss_stale_reviews_on_push = $true
                require_code_owner_review = $true
                require_last_push_approval = $true
                required_approving_review_count = 1
                required_review_thread_resolution = $true
            }
        },
        @{
            type = "required_status_checks"
            parameters = @{
                required_status_checks = @(
                    @{ context = "build-ubuntu-latest" },
                    @{ context = "build-windows-latest" }
                )
                strict_required_status_checks_policy = $true
            }
        }
    )
}

Write-Host "Applying repository ruleset to master and development..." -ForegroundColor Yellow
$existingRuleset = @(
    gh api "repos/$repository/rulesets?includes_parents=false" |
        ConvertFrom-Json |
        Where-Object { $_.name -eq $rulesetName }
) | Select-Object -First 1

$rulesetJson = $ruleset | ConvertTo-Json -Depth 10
if ($existingRuleset) {
    $rulesetJson | gh api -X PUT "repos/$repository/rulesets/$($existingRuleset.id)" --input -
}
else {
    $rulesetJson | gh api -X POST "repos/$repository/rulesets" --input -
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
Write-Host "  3. The merge triggers the first stable publish, or run Publish NuGet"
Write-Host "     manually with an explicit stable version."
