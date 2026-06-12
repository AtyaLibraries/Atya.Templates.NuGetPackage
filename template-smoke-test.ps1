<#
.SYNOPSIS
  Installs this template locally and verifies naming normalization, option
  variants, generated repository lifecycle commands, and naming enforcement.
.EXAMPLE
  ./template-smoke-test.ps1
  ./template-smoke-test.ps1 -KeepOutput
#>
[CmdletBinding()]
param(
    [string]$PackageName = "Contoso.Example",

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

function Get-NormalizedPackageId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return "Atya.$($Name -replace '^[Aa]tya\.', '')"
}

function Get-GeneratedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = (Resolve-Path $Path).Path

    return Get-ChildItem -Path $root -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '\\(\.git|bin|obj|artifacts)\\' } |
        ForEach-Object {
            [pscustomobject]@{
                FullName = $_.FullName
                RelativePath = $_.FullName.Substring($root.Length + 1)
            }
        }
}

function Assert-NoPlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedPackageId
    )

    $generatedFiles = @(Get-GeneratedFiles -Path $Path)
    $placeholderMatches = $generatedFiles.FullName |
        Select-String -Pattern '__PACKAGE_NAME__|__PACKAGE_DESCRIPTION__|__PACKAGE_AUTHORS__|__PACKAGE_COMPANY__|__PACKAGE_TAGS__|__GITHUB_OWNER__|__REPOSITORY_URL__|__PACKAGE_MARKER_NAME__|__INCLUDE_ATYA_GUARDS__|__INCLUDE_ATYA_GOVERNANCE__|Atya\.Templates\.NuGetPackage'

    if ($placeholderMatches) {
        $details = $placeholderMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Template placeholders remain in generated output:`n$($details -join "`n")"
    }

    $bareName = $ExpectedPackageId -replace '^Atya\.', ''
    $bareNamePattern = "(?<!Atya\.)$([regex]::Escape($bareName))"
    $bareNameMatches = $generatedFiles.FullName | Select-String -Pattern $bareNamePattern

    if ($bareNameMatches) {
        $details = $bareNameMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Bare package identifiers remain in generated output:`n$($details -join "`n")"
    }
}

function Assert-GeneratedNaming {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Scenario,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $expectedPackageId = $Scenario.ExpectedPackageId
    Assert-NoPlaceholders -Path $OutputPath -ExpectedPackageId $expectedPackageId

    $expectedFiles = @(
        "$expectedPackageId.sln",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "Directory.Build.targets",
        "docs/RELEASING.md",
        "nuget.config",
        "README.md",
        "SECURITY.md",
        "samples/$expectedPackageId.Samples.Console/$expectedPackageId.Samples.Console.csproj",
        "src/$expectedPackageId/$expectedPackageId.cs",
        "src/$expectedPackageId/$expectedPackageId.csproj",
        "src/$expectedPackageId/Properties/AssemblyInfo.cs",
        "src/$expectedPackageId/icon.png",
        "tests/$expectedPackageId.UnitTests/$expectedPackageId.UnitTests.csproj"
    )

    if ($Scenario.ExpectGitHub) {
        $expectedFiles += @(
            "bootstrap.ps1",
            ".github/CODEOWNERS",
            ".github/pull_request_template.md",
            ".github/release.yml",
            ".github/workflows/ci.yml",
            ".github/workflows/publish-nuget.yml"
        )
    }

    if ($Scenario.ExpectBenchmarks) {
        $expectedFiles += "benchmarks/$expectedPackageId.Benchmarks/$expectedPackageId.Benchmarks.csproj"
    }

    $missingFiles = $expectedFiles | Where-Object {
        -not (Test-Path (Join-Path $OutputPath $_))
    }

    if ($missingFiles) {
        throw "Expected generated files are missing:`n$($missingFiles -join "`n")"
    }

    $benchmarkProject = Join-Path $OutputPath "benchmarks/$expectedPackageId.Benchmarks/$expectedPackageId.Benchmarks.csproj"
    if ($Scenario.ExpectBenchmarks -and -not (Test-Path $benchmarkProject)) {
        throw "Expected benchmark project is missing."
    }

    if (-not $Scenario.ExpectBenchmarks -and (Test-Path $benchmarkProject)) {
        throw "Benchmark project was generated when includeBenchmarks=false."
    }

    $githubPath = Join-Path $OutputPath ".github"
    $bootstrapPath = Join-Path $OutputPath "bootstrap.ps1"
    if (-not $Scenario.ExpectGitHub -and ((Test-Path $githubPath) -or (Test-Path $bootstrapPath))) {
        throw "GitHub files were generated when includeGitHub=false."
    }

    $packageProjectPath = Join-Path $OutputPath "src/$expectedPackageId/$expectedPackageId.csproj"
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $propertyGroup = $packageProject.SelectSingleNode("/Project/PropertyGroup")

    foreach ($propertyName in @("PackageId", "AssemblyName", "RootNamespace")) {
        $actualValue = $propertyGroup.SelectSingleNode($propertyName).InnerText.Trim()
        if ($actualValue -ne $expectedPackageId) {
            throw "Expected $propertyName '$expectedPackageId', found '$actualValue'."
        }
    }

    $assemblyInfo = Get-Content -Path (Join-Path $OutputPath "src/$expectedPackageId/Properties/AssemblyInfo.cs") -Raw
    if ($assemblyInfo -notmatch [regex]::Escape("InternalsVisibleTo(`"$expectedPackageId.UnitTests`")")) {
        throw "InternalsVisibleTo does not reference '$expectedPackageId.UnitTests'."
    }

    $solution = Get-Content -Path (Join-Path $OutputPath "$expectedPackageId.sln") -Raw
    foreach ($projectName in @(
        $expectedPackageId,
        "$expectedPackageId.UnitTests",
        "$expectedPackageId.Samples.Console"
    )) {
        if ($solution -notmatch [regex]::Escape($projectName)) {
            throw "Solution does not reference '$projectName'."
        }
    }

    if ($Scenario.ExpectBenchmarks -and $solution -notmatch [regex]::Escape("$expectedPackageId.Benchmarks")) {
        throw "Solution does not reference '$expectedPackageId.Benchmarks'."
    }

    [xml]$buildProps = Get-Content -Path (Join-Path $OutputPath "Directory.Build.props")
    $targetFramework = $buildProps.SelectSingleNode("/Project/PropertyGroup/TargetFramework").InnerText.Trim()
    if ($targetFramework -ne "net10.0") {
        throw "Expected TargetFramework net10.0, found '$targetFramework'."
    }

    $repositoryUrl = $buildProps.SelectSingleNode("/Project/PropertyGroup/RepositoryUrl").InnerText.Trim()
    $expectedRepositoryUrl = "https://github.com/AtyaLibraries/$expectedPackageId"

    if ($repositoryUrl -ne $expectedRepositoryUrl) {
        throw "Expected RepositoryUrl '$expectedRepositoryUrl', found '$repositoryUrl'."
    }

    if ($Scenario.ExpectGitHub) {
        $ciWorkflow = Get-Content -Path (Join-Path $OutputPath ".github/workflows/ci.yml") -Raw
        foreach ($expectedPath in @(
            "SOLUTION_FILE: ./$expectedPackageId.sln",
            "TEST_PROJECT: ./tests/$expectedPackageId.UnitTests/$expectedPackageId.UnitTests.csproj",
            "PACKAGE_PROJECT: ./src/$expectedPackageId/$expectedPackageId.csproj"
        )) {
            if ($ciWorkflow -notmatch [regex]::Escape($expectedPath)) {
                throw "Generated CI workflow is missing '$expectedPath'."
            }
        }
    }
}

function Invoke-GeneratedLifecycle {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Scenario,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $expectedPackageId = $Scenario.ExpectedPackageId

    Push-Location $OutputPath
    try {
        Invoke-NativeCommand -Description "$($Scenario.Name) git initialization" -Command {
            git init --initial-branch development
            git config user.name "Template Smoke Test"
            git config user.email "template-smoke@example.invalid"
            git remote add origin "https://github.com/AtyaLibraries/$expectedPackageId.git"
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

        Invoke-NativeCommand -Description "$($Scenario.Name) locked-mode restore" -Command {
            dotnet restore "./$expectedPackageId.sln" --verbosity minimal --locked-mode -p:RestoreLockedMode=true
        }

        $packageLock = Get-Content -Path "./src/$expectedPackageId/packages.lock.json" -Raw
        if ($packageLock -notmatch '"MinVer"' -or $packageLock -notmatch '"Microsoft.SourceLink.GitHub"') {
            throw "Generated package lock file is missing MinVer or Microsoft.SourceLink.GitHub."
        }

        Invoke-NativeCommand -Description "$($Scenario.Name) Release build" -Command {
            dotnet build "./$expectedPackageId.sln" --configuration Release --no-restore --verbosity minimal
        }
        Invoke-NativeCommand -Description "$($Scenario.Name) unit tests" -Command {
            dotnet test "./tests/$expectedPackageId.UnitTests/$expectedPackageId.UnitTests.csproj" --configuration Release --no-build --verbosity minimal
        }
        Invoke-NativeCommand -Description "$($Scenario.Name) package creation" -Command {
            dotnet pack "./src/$expectedPackageId/$expectedPackageId.csproj" --configuration Release --no-build --output ./artifacts/packages --verbosity minimal
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
}

function Invoke-SmokeScenario {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Scenario
    )

    $outputPath = Join-Path $scratchRoot $Scenario.Name

    Write-Host "`n[$($Scenario.Name)] Generating $($Scenario.InputName) as $($Scenario.ExpectedPackageId)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputPath | Out-Null

    $newArgs = @(
        "new", "atya-nuget",
        "--name", $Scenario.InputName,
        "--output", $outputPath,
        "--authors", "Smoke Tester",
        "--company", "SmokeCo",
        "--github-owner", "AtyaLibraries",
        "--no-update-check"
    ) + $Scenario.Arguments

    Invoke-NativeCommand -Description "$($Scenario.Name) template generation" -Command {
        dotnet @newArgs
    } | Out-Host

    Assert-GeneratedNaming -Scenario $Scenario -OutputPath $outputPath

    if ($Scenario.RunLifecycle) {
        Invoke-GeneratedLifecycle -Scenario $Scenario -OutputPath $outputPath | Out-Host
    }

    Write-Host "[$($Scenario.Name)] Passed." -ForegroundColor Green
    return $outputPath
}

function Assert-EquivalentGeneratedOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UnprefixedPath,

        [Parameter(Mandatory = $true)]
        [string]$PrefixedPath
    )

    $unprefixedFiles = @(Get-GeneratedFiles -Path $UnprefixedPath)
    $prefixedFiles = @(Get-GeneratedFiles -Path $PrefixedPath)
    $pathDifferences = Compare-Object `
        ($unprefixedFiles.RelativePath | Sort-Object) `
        ($prefixedFiles.RelativePath | Sort-Object)

    if ($pathDifferences) {
        throw "Prefixed and unprefixed inputs produced different file trees:`n$($pathDifferences | Out-String)"
    }

    foreach ($relativePath in $unprefixedFiles.RelativePath) {
        $unprefixedFile = Join-Path $UnprefixedPath $relativePath
        $prefixedFile = Join-Path $PrefixedPath $relativePath

        if ([System.IO.Path]::GetExtension($relativePath) -eq ".png") {
            $unprefixedContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($unprefixedFile))
            $prefixedContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($prefixedFile))
        }
        else {
            $guidPattern = '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
            $unprefixedContent = (Get-Content -Path $unprefixedFile -Raw) -replace $guidPattern, "<GUID>"
            $prefixedContent = (Get-Content -Path $prefixedFile -Raw) -replace $guidPattern, "<GUID>"
        }

        if ($unprefixedContent -cne $prefixedContent) {
            throw "Prefixed and unprefixed inputs produced different content in '$relativePath'."
        }
    }
}

function Assert-InvalidPackageIdFailsFirstBuild {
    $scenario = @{
        Name = "InvalidPackageId"
        InputName = "Contoso.Invalid"
        ExpectedPackageId = "Atya.Contoso.Invalid"
        Arguments = @("--include-benchmarks", "false", "--include-github", "false")
        ExpectBenchmarks = $false
        ExpectGitHub = $false
    }
    $outputPath = Join-Path $scratchRoot $scenario.Name

    Write-Host "`n[InvalidPackageId] Verifying first-build naming failure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputPath | Out-Null

    $newArgs = @(
        "new", "atya-nuget",
        "--name", $scenario.InputName,
        "--output", $outputPath,
        "--no-update-check"
    ) + $scenario.Arguments

    Invoke-NativeCommand -Description "InvalidPackageId template generation" -Command {
        dotnet @newArgs
    }
    Assert-GeneratedNaming -Scenario $scenario -OutputPath $outputPath

    $packageProjectPath = Join-Path $outputPath "src/$($scenario.ExpectedPackageId)/$($scenario.ExpectedPackageId).csproj"
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $packageProject.SelectSingleNode("/Project/PropertyGroup/PackageId").InnerText = "ContosoExample"
    $packageProject.Save($packageProjectPath)

    Push-Location $outputPath
    try {
        $buildLines = & dotnet build "./$($scenario.ExpectedPackageId).sln" --configuration Release --verbosity minimal 2>&1
        $buildExitCode = $LASTEXITCODE
        $buildOutput = $buildLines | Out-String
    }
    finally {
        Pop-Location
    }

    if ($buildExitCode -eq 0) {
        throw "A generated repository with invalid PackageId 'ContosoExample' built successfully."
    }

    $expectedError = "PackageId 'ContosoExample' is invalid."
    if ($buildOutput -notmatch [regex]::Escape($expectedError) -or
        $buildOutput -notmatch "SkipPackageNamingValidation=true") {
        throw "Invalid PackageId build did not emit the actionable naming error:`n$buildOutput"
    }

    Write-Host "[InvalidPackageId] Passed." -ForegroundColor Green
}

$baselinePackageId = Get-NormalizedPackageId -Name $PackageName
$scenarios = @(
    @{
        Name = "Baseline"
        InputName = $PackageName
        ExpectedPackageId = $baselinePackageId
        Arguments = @()
        ExpectBenchmarks = $true
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "Prefixed"
        InputName = $baselinePackageId
        ExpectedPackageId = $baselinePackageId
        Arguments = @()
        ExpectBenchmarks = $true
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "NoBenchmarks"
        InputName = "Contoso.NoBenchmarks"
        ExpectedPackageId = "Atya.Contoso.NoBenchmarks"
        Arguments = @("--include-benchmarks", "false")
        ExpectBenchmarks = $false
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "NoGitHub"
        InputName = "Contoso.NoGitHub"
        ExpectedPackageId = "Atya.Contoso.NoGitHub"
        Arguments = @("--include-github", "false")
        ExpectBenchmarks = $true
        ExpectGitHub = $false
        RunLifecycle = $true
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
    $scenarioOutputs = @{}
    foreach ($scenario in $scenarios) {
        $scenarioOutputs[$scenario.Name] = Invoke-SmokeScenario -Scenario $scenario
    }

    Assert-EquivalentGeneratedOutput `
        -UnprefixedPath $scenarioOutputs.Baseline `
        -PrefixedPath $scenarioOutputs.Prefixed
    Write-Host "[Idempotence] Prefixed and unprefixed output matched." -ForegroundColor Green

    Assert-InvalidPackageIdFailsFirstBuild

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
