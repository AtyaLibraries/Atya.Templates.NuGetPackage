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

gh api -X PATCH "repos/$repository" `
    -f default_branch=development `
    -F allow_squash_merge=true `
    -F allow_merge_commit=true `
    -F allow_rebase_merge=false | Out-Null

$requiredStatusChecks = @{
    # ci.yml names the matrix job build-${{ matrix.os }}, producing these check contexts.
    required_status_checks = @(
        @{ context = "build-ubuntu-latest" },
        @{ context = "build-windows-latest" }
    )
    strict_required_status_checks_policy = $true
}

$masterRequiredStatusChecks = @{
    required_status_checks = @(
        @{ context = "build-ubuntu-latest" },
        @{ context = "build-windows-latest" },
        @{ context = "release-source" }
    )
    strict_required_status_checks_policy = $true
}

$pullRequestDefaults = @{
    dismiss_stale_reviews_on_push = $true
    require_code_owner_review = $false
    require_last_push_approval = $false
    required_approving_review_count = 0
    required_review_thread_resolution = $true
}

$rulesets = @(
    @{
        name = "Protect development"
        target = "branch"
        enforcement = "active"
        bypass_actors = @()
        conditions = @{
            ref_name = @{
                include = @("refs/heads/development")
                exclude = @()
            }
        }
        rules = @(
            @{ type = "deletion" },
            @{ type = "non_fast_forward" },
            @{ type = "required_linear_history" },
            @{
                type = "pull_request"
                parameters = $pullRequestDefaults + @{
                    allowed_merge_methods = @("squash")
                }
            },
            @{
                type = "required_status_checks"
                parameters = $requiredStatusChecks
            }
        )
    },
    @{
        name = "Protect master"
        target = "branch"
        enforcement = "active"
        bypass_actors = @()
        conditions = @{
            ref_name = @{
                include = @("refs/heads/master")
                exclude = @()
            }
        }
        rules = @(
            @{ type = "deletion" },
            @{ type = "non_fast_forward" },
            @{
                type = "pull_request"
                parameters = $pullRequestDefaults + @{
                    allowed_merge_methods = @("merge")
                }
            },
            @{
                type = "required_status_checks"
                parameters = $masterRequiredStatusChecks
            }
        )
    }
)

Write-Host "Applying repository rulesets to development and master..." -ForegroundColor Yellow
$existingRulesets = @(
    gh api "repos/$repository/rulesets?includes_parents=false" |
        ConvertFrom-Json
)

$legacyRuleset = $existingRulesets | Where-Object { $_.name -eq "Protected branches" } |
    Select-Object -First 1
if ($legacyRuleset) {
    gh api -X DELETE "repos/$repository/rulesets/$($legacyRuleset.id)"
}

foreach ($ruleset in $rulesets) {
    $existingRuleset = $existingRulesets | Where-Object { $_.name -eq $ruleset.name } |
        Select-Object -First 1
    $rulesetPath = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).json"

    try {
        [System.IO.File]::WriteAllText(
            $rulesetPath,
            ($ruleset | ConvertTo-Json -Depth 10),
            [System.Text.UTF8Encoding]::new($false)
        )

        if ($existingRuleset) {
            gh api -X PUT "repos/$repository/rulesets/$($existingRuleset.id)" --input $rulesetPath |
                Out-Null
        }
        else {
            gh api -X POST "repos/$repository/rulesets" --input $rulesetPath | Out-Null
        }
    }
    finally {
        Remove-Item -LiteralPath $rulesetPath -Force -ErrorAction SilentlyContinue
    }
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
