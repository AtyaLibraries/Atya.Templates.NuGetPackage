<#
.SYNOPSIS
  Installs this template locally and verifies default and option-specific
  generated repositories can restore, build, test, and pack.
.EXAMPLE
  ./template-smoke-test.ps1
  ./template-smoke-test.ps1 -KeepOutput
#>
[CmdletBinding()]
param(
    [string]$PackageName = "Atya.SmokeTest.Pkg",

    [switch]$KeepOutput
)

$ErrorActionPreference = "Stop"
$templateRoot = $PSScriptRoot
$repoRoot = Resolve-Path $templateRoot
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "atya-nuget-smoke-$([guid]::NewGuid().ToString('N').Substring(0, 8))"

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Assert-NoPlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $placeholderMatches = Get-ChildItem -Path $Path -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|artifacts)\\' } |
        Select-String -Pattern '__PACKAGE_NAME__|__PACKAGE_DESCRIPTION__|__PACKAGE_AUTHORS__|__PACKAGE_COMPANY__|__PACKAGE_TAGS__|__GITHUB_OWNER__|__REPOSITORY_URL__|__PACKAGE_MARKER_NAME__|Atya\.Templates\.NuGetPackage'

    if ($placeholderMatches) {
        $details = $placeholderMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Template placeholders remain in generated output:`n$($details -join "`n")"
    }
}

function Invoke-SmokeScenario {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Scenario
    )

    $scenarioName = $Scenario.Name
    $generatedName = "$PackageName.$scenarioName"
    $outputPath = Join-Path $scratchRoot $scenarioName

    Write-Host "`n[$scenarioName] Generating $generatedName..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputPath | Out-Null

    $newArgs = @(
        "new", "atya-nuget",
        "--name", $generatedName,
        "--output", $outputPath,
        "--authors", "Smoke Tester",
        "--company", "SmokeCo",
        "--github-owner", "AtyaLibraries"
    ) + $Scenario.Arguments

    Invoke-NativeCommand -Description "$scenarioName template generation" -Command {
        dotnet @newArgs
    }

    Assert-NoPlaceholders -Path $outputPath

    $expectedFiles = @(
        "bootstrap.ps1",
        "CHANGELOG.md",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "docs/RELEASING.md",
        ".github/CODEOWNERS",
        ".github/pull_request_template.md",
        ".github/release.yml",
        ".github/workflows/delete-merged-branch.yml",
        "nuget.config",
        "src/$generatedName/$generatedName.cs",
        "src/$generatedName/Properties/AssemblyInfo.cs",
        "src/$generatedName/icon.png"
    )

    $missingFiles = $expectedFiles | Where-Object {
        -not (Test-Path (Join-Path $outputPath $_))
    }

    if ($missingFiles) {
        throw "Expected generated files are missing:`n$($missingFiles -join "`n")"
    }

    $benchmarkProject = Join-Path $outputPath "benchmarks/$generatedName.Benchmarks/$generatedName.Benchmarks.csproj"
    if ($Scenario.ExpectBenchmarks -and -not (Test-Path $benchmarkProject)) {
        throw "Expected benchmark project is missing."
    }

    if (-not $Scenario.ExpectBenchmarks -and (Test-Path $benchmarkProject)) {
        throw "Benchmark project was generated when includeBenchmarks=false."
    }

    $packageProjectPath = Join-Path $outputPath "src/$generatedName/$generatedName.csproj"
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $packageId = $packageProject.SelectSingleNode("/Project/PropertyGroup/PackageId").InnerText.Trim()

    if ($packageId -ne $generatedName) {
        throw "Expected PackageId '$generatedName', found '$packageId'."
    }

    $guardReference = $packageProject.SelectSingleNode(
        "/Project/ItemGroup/PackageReference[@Include='Atya.Foundation.Guards']"
    )
    $codeQualityReference = $packageProject.SelectSingleNode(
        "/Project/ItemGroup/PackageReference[@Include='Atya.Governance.CodeQuality']"
    )

    if (-not $guardReference -or $guardReference.HasAttribute("Condition")) {
        throw "Atya.Foundation.Guards must be an unconditional package reference."
    }

    if (-not $codeQualityReference -or $codeQualityReference.HasAttribute("Condition")) {
        throw "Atya.Governance.CodeQuality must be an unconditional package reference."
    }

    $testProjectPath = Join-Path $outputPath "tests/$generatedName.UnitTests/$generatedName.UnitTests.csproj"
    [xml]$testProject = Get-Content -Path $testProjectPath
    $testingReference = $testProject.SelectSingleNode(
        "/Project/ItemGroup/PackageReference[@Include='Atya.Governance.Testing']"
    )

    if (-not $testingReference -or $testingReference.HasAttribute("Condition")) {
        throw "Atya.Governance.Testing must be an unconditional package reference."
    }

    [xml]$buildProps = Get-Content -Path (Join-Path $outputPath "Directory.Build.props")
    $targetFramework = $buildProps.SelectSingleNode("/Project/PropertyGroup/TargetFramework").InnerText.Trim()
    if ($targetFramework -ne "net10.0") {
        throw "Expected TargetFramework net10.0, found '$targetFramework'."
    }

    $repositoryUrl = $buildProps.SelectSingleNode("/Project/PropertyGroup/RepositoryUrl").InnerText.Trim()
    $expectedRepositoryUrl = "https://github.com/AtyaLibraries/$generatedName"

    if ($repositoryUrl -ne $expectedRepositoryUrl) {
        throw "Expected RepositoryUrl '$expectedRepositoryUrl', found '$repositoryUrl'."
    }

    Push-Location $outputPath
    try {
        $preGitBuildOutput = @(
            dotnet build "./$generatedName.sln" --configuration Release --no-restore --verbosity minimal 2>&1
        )
        $preGitBuildExitCode = $LASTEXITCODE
        $preGitBuildText = $preGitBuildOutput -join [Environment]::NewLine
        Write-Host $preGitBuildText

        if ($preGitBuildExitCode -ne 0) {
            throw "$scenarioName pre-Git Release build failed with exit code $preGitBuildExitCode."
        }

        if ($preGitBuildText -match 'MINVER1001|Unable to locate repository|Source control information is not available') {
            throw "$scenarioName pre-Git Release build emitted a MinVer or SourceLink repository warning."
        }

        Invoke-NativeCommand -Description "$scenarioName git initialization" -Command {
            git init --initial-branch development
            git config user.name "Template Smoke Test"
            git config user.email "template-smoke@example.invalid"
            git remote add origin "https://github.com/AtyaLibraries/$generatedName.git"
            git add .
            git -c commit.gpgsign=false commit -m "chore: initialize smoke-test repository"
        }
        $projectDirectories = Get-ChildItem -Path . -Recurse -Filter "*.csproj" -File |
            ForEach-Object { $_.Directory.FullName }
        $missingLocks = $projectDirectories | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $_ "packages.lock.json"))
        }

        if ($missingLocks) {
            throw "The post-generation restore did not create a lock file for every project:`n$($missingLocks -join "`n")"
        }

        Invoke-NativeCommand -Description "$scenarioName locked-mode restore" -Command {
            dotnet restore "./$generatedName.sln" --verbosity minimal --locked-mode -p:RestoreLockedMode=true
        }

        $packageLock = Get-Content -Path "./src/$generatedName/packages.lock.json" -Raw
        if (
            $packageLock -notmatch '"Atya.Foundation.Guards"' -or
            $packageLock -notmatch '"Atya.Governance.CodeQuality"' -or
            $packageLock -notmatch '"MinVer"' -or
            $packageLock -notmatch '"Microsoft.SourceLink.GitHub"'
        ) {
            throw "Generated package lock file is missing a required library dependency."
        }

        $testLock = Get-Content -Path "./tests/$generatedName.UnitTests/packages.lock.json" -Raw
        if ($testLock -notmatch '"Atya.Governance.Testing"') {
            throw "Generated test lock file is missing Atya.Governance.Testing."
        }

        Invoke-NativeCommand -Description "$scenarioName Release build" -Command {
            dotnet build "./$generatedName.sln" --configuration Release --no-restore --verbosity minimal
        }
        Invoke-NativeCommand -Description "$scenarioName unit tests" -Command {
            dotnet test "./tests/$generatedName.UnitTests/$generatedName.UnitTests.csproj" --configuration Release --no-build --verbosity minimal
        }
        Invoke-NativeCommand -Description "$scenarioName package creation" -Command {
            dotnet pack "./src/$generatedName/$generatedName.csproj" --configuration Release --no-build --output ./artifacts/packages --verbosity minimal
        }

        $nupkg = @(Get-ChildItem -Path ./artifacts/packages -Filter "*.nupkg")
        $snupkg = @(Get-ChildItem -Path ./artifacts/packages -Filter "*.snupkg")

        if ($nupkg.Count -ne 1) {
            throw "Expected exactly one .nupkg, found $($nupkg.Count)."
        }

        if ($snupkg.Count -ne 1) {
            throw "Expected exactly one .snupkg, found $($snupkg.Count)."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "[$scenarioName] Passed." -ForegroundColor Green
}

$scenarios = @(
    @{
        Name = "Baseline"
        Arguments = @()
        ExpectBenchmarks = $true
    },
    @{
        Name = "NoBenchmarks"
        Arguments = @("--include-benchmarks", "false")
        ExpectBenchmarks = $false
    }
)

Write-Host "Template root: $templateRoot" -ForegroundColor Cyan
Write-Host "Repo root    : $repoRoot" -ForegroundColor Cyan
Write-Host "Scratch root : $scratchRoot" -ForegroundColor Cyan

try {
    Write-Host "`nInstalling template from $repoRoot..." -ForegroundColor Yellow
    Invoke-NativeCommand -Description "Template installation" -Command {
        dotnet new install "$repoRoot" --force | Out-Null
    }

    New-Item -ItemType Directory -Path $scratchRoot | Out-Null
    foreach ($scenario in $scenarios) {
        Invoke-SmokeScenario -Scenario $scenario
    }

    Write-Host "`n[OK] All template smoke-test scenarios passed." -ForegroundColor Green
}
finally {
    if (-not $KeepOutput -and (Test-Path $scratchRoot)) {
        Remove-Item -Recurse -Force $scratchRoot
        Write-Host "Cleaned scratch root." -ForegroundColor DarkGray
    }
    elseif ($KeepOutput) {
        Write-Host "Scratch root kept at: $scratchRoot" -ForegroundColor DarkGray
    }
}
