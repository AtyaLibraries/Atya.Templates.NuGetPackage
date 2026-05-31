<#
.SYNOPSIS
  Installs this template locally, generates a throwaway package from it, and
  verifies the generated repository can restore, build, test, pack, and generate
  without unresolved template placeholders.
.NOTES
  Run this after any change to the template files. This is the closest thing
  to a CI check for the template repo.
.EXAMPLE
  ./template-smoke-test.ps1
  ./template-smoke-test.ps1 -Framework net10.0 -KeepOutput
  ./template-smoke-test.ps1 -ExcludeBenchmarks
#>
[CmdletBinding()]
param(
    [ValidateSet("net10.0")]
    [string]$Framework = "net10.0",

    [string]$PackageName = "Atya.SmokeTest.Pkg",

    [switch]$KeepOutput,

    [switch]$ExcludeBenchmarks
)

$ErrorActionPreference = "Stop"
$templateRoot  = $PSScriptRoot
$repoRoot      = Resolve-Path $templateRoot
$scratch       = Join-Path ([System.IO.Path]::GetTempPath()) "atya-nuget-smoke-$([guid]::NewGuid().ToString('N').Substring(0,8))"

Write-Host "Template root: $templateRoot" -ForegroundColor Cyan
Write-Host "Repo root    : $repoRoot" -ForegroundColor Cyan
Write-Host "Scratch dir  : $scratch" -ForegroundColor Cyan

try {
    Write-Host "`n[1/6] Installing template from $repoRoot..." -ForegroundColor Yellow
    dotnet new install "$repoRoot" --force | Out-Null

    Write-Host "`n[2/6] Generating package '$PackageName' into $scratch..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $newArgs = @(
        "new", "atya-nuget",
        "--name", $PackageName,
        "--output", $scratch,
        "--framework", $Framework,
        "--authors", "Smoke Tester",
        "--company", "SmokeCo",
        "--github-owner", "AtyaLibraries",
        "--repository", "https://example.invalid/$PackageName",
        "--skip-restore"
    )

    if ($ExcludeBenchmarks) {
        $newArgs += @("--include-benchmarks", "false")
    }

    dotnet @newArgs

    Write-Host "`n[3/6] Verifying no unresolved template placeholders remain..." -ForegroundColor Yellow
    $placeholderMatches = Get-ChildItem -Path $scratch -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|artifacts)\\' } |
        Select-String -Pattern '__PACKAGE_NAME__|__PACKAGE_DESCRIPTION__|__PACKAGE_AUTHORS__|__PACKAGE_COMPANY__|__PACKAGE_TAGS__|__GITHUB_OWNER__|__REPOSITORY_URL__|__PACKAGE_MARKER_NAME__'

    if ($placeholderMatches) {
        $details = $placeholderMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Template placeholders remain in generated output:`n$($details -join "`n")"
    }

    Write-Host "`n[4/6] Verifying generated repository scaffolding..." -ForegroundColor Yellow
    $expectedFiles = @(
        "bootstrap.ps1",
        "CHANGELOG.md",
        "SECURITY.md",
        "CONTRIBUTING.md",
        ".github/CODEOWNERS",
        ".github/pull_request_template.md",
        ".github/release.yml",
        "nuget.config",
        "src/$PackageName/$PackageName.cs",
        "src/$PackageName/Properties/AssemblyInfo.cs"
    )

    $missingFiles = $expectedFiles | Where-Object {
        -not (Test-Path (Join-Path $scratch $_))
    }

    if ($missingFiles) {
        throw "Expected generated files are missing:`n$($missingFiles -join "`n")"
    }

    Write-Host "`n[5/6] Building and testing generated repository..." -ForegroundColor Yellow
    Push-Location $scratch
    try {
        dotnet restore ".\$PackageName.sln" --verbosity minimal
        dotnet build ".\$PackageName.sln" --configuration Release --no-restore --verbosity minimal
        dotnet test ".\tests\$PackageName.UnitTests\$PackageName.UnitTests.csproj" --configuration Release --no-build --verbosity minimal
    }
    finally {
        Pop-Location
    }

    Write-Host "`n[6/6] Packing generated repository..." -ForegroundColor Yellow
    Push-Location $scratch
    try {
        dotnet pack ".\src\$PackageName\$PackageName.csproj" --configuration Release --no-build --output .\artifacts\packages --verbosity minimal

        $nupkg = Get-ChildItem -Path .\artifacts\packages -Filter "*.nupkg"
        $snupkg = Get-ChildItem -Path .\artifacts\packages -Filter "*.snupkg"

        if ($nupkg.Count -ne 1) {
            throw "Expected exactly one .nupkg, found $($nupkg.Count)."
        }

        if ($snupkg.Count -ne 1) {
            throw "Expected exactly one .snupkg, found $($snupkg.Count)."
        }

        Get-ChildItem .\artifacts\packages | Format-Table Name, Length
    }
    finally {
        Pop-Location
    }

    Write-Host "`n[OK] Template smoke test passed." -ForegroundColor Green
}
finally {
    if (-not $KeepOutput -and (Test-Path $scratch)) {
        Remove-Item -Recurse -Force $scratch
        Write-Host "Cleaned scratch dir." -ForegroundColor DarkGray
    }
    elseif ($KeepOutput) {
        Write-Host "Scratch dir kept at: $scratch" -ForegroundColor DarkGray
    }
}
