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
    [string]$PackageName = "Foundation.Caching",

    [switch]$KeepOutput
)

$ErrorActionPreference = "Stop"
$templateRoot = $PSScriptRoot
$repoRoot = Resolve-Path $templateRoot
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "atya-nuget-smoke-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$templateHive = Join-Path $scratchRoot ".template-hive"

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

function Get-ShortName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($Name -replace '^.*\.', '')
}

function Get-MSBuildProperty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    $propertyLines = & dotnet msbuild $ProjectPath "-getProperty:$PropertyName" -nologo 2>&1
    if ($LASTEXITCODE -ne 0) {
        $details = $propertyLines | Out-String
        throw "Failed to evaluate MSBuild property '$PropertyName' for '$ProjectPath':`n$details"
    }

    return ($propertyLines | Out-String).Trim()
}

function Get-GeneratedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = (Resolve-Path $Path).Path

    return Get-ChildItem -Path $root -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|bin|obj|artifacts)[\\/]' } |
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
        [string]$ExpectedShortName
    )

    $generatedFiles = @(Get-GeneratedFiles -Path $Path)
    $forbiddenPattern = @(
        '__PACKAGE_NAME__',
        '__PACKAGE_DESCRIPTION__',
        '__PACKAGE_AUTHORS__',
        '__PACKAGE_COMPANY__',
        '__PACKAGE_TAGS__',
        '__GITHUB_OWNER__',
        '__REPOSITORY_URL__',
        '__PACKAGE_MARKER_NAME__',
        'Atya\.Templates\.NuGetPackage',
        '\bNuGetPackage\b',
        "Atya\.Templates\.$([regex]::Escape($ExpectedShortName))",
        'Atya\.Atya'
    ) -join '|'
    $placeholderMatches = $generatedFiles.FullName |
        Select-String -Pattern $forbiddenPattern

    if ($placeholderMatches) {
        $details = $placeholderMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Template placeholders or mixed naming tokens remain in generated output:`n$($details -join "`n")"
    }

    $invalidPaths = $generatedFiles.RelativePath | Where-Object {
        $_ -match 'Atya\.Templates\.NuGetPackage|\bNuGetPackage\b|Atya\.Atya'
    }

    if ($invalidPaths) {
        throw "Template or mixed naming tokens remain in generated paths:`n$($invalidPaths -join "`n")"
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
    $expectedShortName = $Scenario.ExpectedShortName
    Assert-NoPlaceholders `
        -Path $OutputPath `
        -ExpectedShortName $expectedShortName

    $expectedFiles = @(
        "$expectedShortName.sln",
        "CHANGELOG.md",
        "Directory.Packages.props",
        "docs/RELEASING.md",
        "global.json",
        "nuget.config",
        "README.md",
        "samples/$expectedShortName.Samples.Console/$expectedShortName.Samples.Console.csproj",
        "src/$expectedShortName/$expectedShortName.cs",
        "src/$expectedShortName/$expectedShortName.csproj",
        "src/$expectedShortName/Properties/AssemblyInfo.cs",
        "src/$expectedShortName/icon.png",
        "tests/$expectedShortName.UnitTests/$expectedShortName.UnitTests.csproj"
    )

    if ($Scenario.ExpectGitHub) {
        $expectedFiles += @(
            "bootstrap.ps1",
            "renovate.json",
            ".github/CODEOWNERS",
            ".github/release.yml",
            ".github/workflows/ci.yml",
            ".github/workflows/publish-nuget.yml"
        )
    }

    if ($Scenario.ExpectBenchmarks) {
        $expectedFiles += "benchmarks/$expectedShortName.Benchmarks/$expectedShortName.Benchmarks.csproj"
    }

    $missingFiles = $expectedFiles | Where-Object {
        -not (Test-Path (Join-Path $OutputPath $_))
    }

    if ($missingFiles) {
        throw "Expected generated files are missing:`n$($missingFiles -join "`n")"
    }

    $inheritedCommunityFiles = @(
        "CONTRIBUTING.md",
        "SECURITY.md",
        ".github/pull_request_template.md",
        ".github/ISSUE_TEMPLATE"
    ) | Where-Object {
        Test-Path (Join-Path $OutputPath $_)
    }

    if ($inheritedCommunityFiles) {
        throw "Generated output contains community-health files that should be inherited from AtyaLibraries/.github:`n$($inheritedCommunityFiles -join "`n")"
    }

    $removedBuildFiles = @("Directory.Build.props", "Directory.Build.targets") | Where-Object {
        Test-Path (Join-Path $OutputPath $_)
    }

    if ($removedBuildFiles) {
        throw "Generated output still contains root build files that should come from Atya.Build.Sdk:`n$($removedBuildFiles -join "`n")"
    }

    $benchmarkProject = Join-Path $OutputPath "benchmarks/$expectedShortName.Benchmarks/$expectedShortName.Benchmarks.csproj"
    if ($Scenario.ExpectBenchmarks -and -not (Test-Path $benchmarkProject)) {
        throw "Expected benchmark project is missing."
    }

    if (-not $Scenario.ExpectBenchmarks -and (Test-Path $benchmarkProject)) {
        throw "Benchmark project was generated when includeBenchmarks=false."
    }

    $githubPath = Join-Path $OutputPath ".github"
    $bootstrapPath = Join-Path $OutputPath "bootstrap.ps1"
    $renovatePath = Join-Path $OutputPath "renovate.json"
    if (-not $Scenario.ExpectGitHub -and ((Test-Path $githubPath) -or (Test-Path $bootstrapPath) -or (Test-Path $renovatePath))) {
        throw "GitHub files were generated when includeGitHub=false."
    }

    $packageProjectPath = Join-Path $OutputPath "src/$expectedShortName/$expectedShortName.csproj"
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $packageProjectSdk = $packageProject.DocumentElement.GetAttribute("Sdk")
    if ($packageProjectSdk -ne "Atya.Build.Sdk") {
        throw "Expected package project SDK 'Atya.Build.Sdk', found '$packageProjectSdk'."
    }

    $propertyGroup = $packageProject.SelectSingleNode("/Project/PropertyGroup")

    foreach ($propertyName in @("PackageId", "AssemblyName", "RootNamespace")) {
        $actualValue = $propertyGroup.SelectSingleNode($propertyName).InnerText.Trim()
        if ($actualValue -ne $expectedPackageId) {
            throw "Expected $propertyName '$expectedPackageId', found '$actualValue'."
        }
    }

    $globalJson = Get-Content -Path (Join-Path $OutputPath "global.json") -Raw | ConvertFrom-Json
    $buildSdkVersion = $globalJson.'msbuild-sdks'.'Atya.Build.Sdk'
    if ($buildSdkVersion -ne "1.3.0") {
        throw "Expected global.json to pin Atya.Build.Sdk 1.3.0, found '$buildSdkVersion'."
    }

    $targetFramework = Get-MSBuildProperty -ProjectPath $packageProjectPath -PropertyName "TargetFramework"
    if ($targetFramework -ne "net10.0") {
        throw "Expected TargetFramework net10.0, found '$targetFramework'."
    }

    $repositoryUrlNode = $propertyGroup.SelectSingleNode("RepositoryUrl")
    if ($null -eq $repositoryUrlNode) {
        throw "Generated package project is missing RepositoryUrl."
    }

    $repositoryUrl = $repositoryUrlNode.InnerText.Trim()
    $expectedRepositoryUrl = "https://github.com/AtyaLibraries/$expectedPackageId"

    if ($repositoryUrl -ne $expectedRepositoryUrl) {
        throw "Expected RepositoryUrl '$expectedRepositoryUrl', found '$repositoryUrl'."
    }

    $packageReferences = @($packageProject.SelectNodes("/Project/ItemGroup/PackageReference") | ForEach-Object { $_.GetAttribute("Include") })
    foreach ($forbiddenReference in @("Atya.Governance.CodeQuality", "MinVer", "Microsoft.SourceLink.GitHub")) {
        if ($packageReferences -contains $forbiddenReference) {
            throw "Generated package project should not directly reference '$forbiddenReference'."
        }
    }

    if ($packageReferences -notcontains "Atya.Foundation.Guards") {
        throw "Generated package project is missing the Atya.Foundation.Guards runtime reference."
    }

    $testProjectPath = Join-Path $OutputPath "tests/$expectedShortName.UnitTests/$expectedShortName.UnitTests.csproj"
    [xml]$testProject = Get-Content -Path $testProjectPath
    $testProjectSdk = $testProject.DocumentElement.GetAttribute("Sdk")
    if ($testProjectSdk -ne "Atya.Build.Sdk") {
        throw "Expected test project SDK 'Atya.Build.Sdk', found '$testProjectSdk'."
    }

    $testPackageReferences = @($testProject.SelectNodes("/Project/ItemGroup/PackageReference") | ForEach-Object { $_.GetAttribute("Include") })
    if ($testPackageReferences -contains "Atya.Governance.Testing") {
        throw "Generated test project should not directly reference Atya.Governance.Testing."
    }

    $assemblyInfo = Get-Content -Path (Join-Path $OutputPath "src/$expectedShortName/Properties/AssemblyInfo.cs") -Raw
    if ($assemblyInfo -notmatch [regex]::Escape("InternalsVisibleTo(`"$expectedShortName.UnitTests`")")) {
        throw "InternalsVisibleTo does not reference '$expectedShortName.UnitTests'."
    }

    $solution = Get-Content -Path (Join-Path $OutputPath "$expectedShortName.sln") -Raw
    foreach ($projectName in @(
        $expectedShortName,
        "$expectedShortName.UnitTests",
        "$expectedShortName.Samples.Console"
    )) {
        if ($solution -notmatch [regex]::Escape($projectName)) {
            throw "Solution does not reference '$projectName'."
        }
    }

    if ($Scenario.ExpectBenchmarks -and $solution -notmatch [regex]::Escape("$expectedShortName.Benchmarks")) {
        throw "Solution does not reference '$expectedShortName.Benchmarks'."
    }

    $namespaceDeclarations = Get-ChildItem -Path $OutputPath -Recurse -Filter "*.cs" -File |
        Select-String -Pattern '^\s*namespace\s+([^;{]+)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
    $invalidNamespaces = $namespaceDeclarations | Where-Object {
        $_ -ne $expectedPackageId -and -not $_.StartsWith("$expectedPackageId.", [StringComparison]::Ordinal)
    }

    if ($invalidNamespaces) {
        throw "Generated C# namespaces do not use FULL_ID '$expectedPackageId':`n$($invalidNamespaces -join "`n")"
    }

    if ($Scenario.ExpectGitHub) {
        $codeOwners = Get-Content -Path (Join-Path $OutputPath ".github/CODEOWNERS") -Raw
        foreach ($expectedLine in @(
            "* @AtyaLibraries/maintainers",
            "/.github/ @AtyaLibraries/maintainers",
            "/.github/workflows/ @AtyaLibraries/maintainers"
        )) {
            if ($codeOwners -notmatch [regex]::Escape($expectedLine)) {
                throw "Generated CODEOWNERS is missing '$expectedLine'."
            }
        }

        $ciWorkflow = Get-Content -Path (Join-Path $OutputPath ".github/workflows/ci.yml") -Raw
        foreach ($expectedPath in @(
            "uses: AtyaLibraries/github-workflows/.github/workflows/dotnet-package-ci.yml",
            "solution: ./$expectedShortName.sln",
            "test-project: ./tests/$expectedShortName.UnitTests/$expectedShortName.UnitTests.csproj",
            "package-project: ./src/$expectedShortName/$expectedShortName.csproj"
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
    $expectedShortName = $Scenario.ExpectedShortName

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
            dotnet restore "./$expectedShortName.sln" --verbosity minimal --locked-mode -p:RestoreLockedMode=true
        }

        $packageLock = Get-Content -Path "./src/$expectedShortName/packages.lock.json" -Raw
        if ($packageLock -notmatch '"MinVer"' -or $packageLock -notmatch '"Microsoft.SourceLink.GitHub"') {
            throw "Generated package lock file is missing MinVer or Microsoft.SourceLink.GitHub."
        }

        Invoke-NativeCommand -Description "$($Scenario.Name) Release build" -Command {
            dotnet build "./$expectedShortName.sln" --configuration Release --no-restore --verbosity minimal
        }
        Invoke-NativeCommand -Description "$($Scenario.Name) unit tests" -Command {
            dotnet test "./tests/$expectedShortName.UnitTests/$expectedShortName.UnitTests.csproj" --configuration Release --no-build --verbosity minimal
        }
        Invoke-NativeCommand -Description "$($Scenario.Name) package creation" -Command {
            dotnet pack "./src/$expectedShortName/$expectedShortName.csproj" --configuration Release --no-build --output ./artifacts/packages --verbosity minimal
        }

        $nupkg = @(Get-ChildItem -Path ./artifacts/packages -Filter "*.nupkg")
        $snupkg = @(Get-ChildItem -Path ./artifacts/packages -Filter "*.snupkg")

        if ($nupkg.Count -ne 1) {
            throw "Expected exactly one .nupkg, found $($nupkg.Count)."
        }

        if ($snupkg.Count -ne 1) {
            throw "Expected exactly one .snupkg, found $($snupkg.Count)."
        }

        if ($nupkg[0].Name -notmatch "^$([regex]::Escape($expectedPackageId))\..+\.nupkg$") {
            throw "Package '$($nupkg[0].Name)' does not use PackageId '$expectedPackageId'."
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $packageArchive = [System.IO.Compression.ZipFile]::OpenRead($nupkg[0].FullName)
        try {
            $expectedAssemblyPath = "lib/net10.0/$expectedPackageId.dll"
            if (-not ($packageArchive.Entries | Where-Object { $_.FullName -eq $expectedAssemblyPath })) {
                throw "Package '$($nupkg[0].Name)' does not contain '$expectedAssemblyPath'."
            }
        }
        finally {
            $packageArchive.Dispose()
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
        "--no-update-check",
        "--debug:custom-hive", $templateHive
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

function Assert-BuildFailsWithNamingError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$SolutionName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedError,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Push-Location $OutputPath
    try {
        $buildLines = & dotnet build "./$SolutionName.sln" --configuration Release --verbosity minimal 2>&1
        $buildExitCode = $LASTEXITCODE
        $buildOutput = $buildLines | Out-String
    }
    finally {
        Pop-Location
    }

    if ($buildExitCode -eq 0) {
        throw "$Description built successfully when it should have failed."
    }

    if ($buildOutput -notmatch [regex]::Escape($ExpectedError) -or
        $buildOutput -notmatch "SkipPackageNamingValidation=true") {
        throw "$Description did not emit the actionable naming error:`n$buildOutput"
    }
}

function Assert-NamingGuardsFailFirstBuild {
    $scenario = @{
        Name = "NamingGuards"
        InputName = "Contoso.GuardCheck"
        ExpectedPackageId = "Atya.Contoso.GuardCheck"
        ExpectedShortName = "GuardCheck"
        Arguments = @("--include-benchmarks", "false", "--include-github", "false")
        ExpectBenchmarks = $false
        ExpectGitHub = $false
    }
    $outputPath = Join-Path $scratchRoot $scenario.Name

    Write-Host "`n[NamingGuards] Verifying first-build naming failures..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputPath | Out-Null

    $newArgs = @(
        "new", "atya-nuget",
        "--name", $scenario.InputName,
        "--output", $outputPath,
        "--no-update-check",
        "--debug:custom-hive", $templateHive
    ) + $scenario.Arguments

    Invoke-NativeCommand -Description "NamingGuards template generation" -Command {
        dotnet @newArgs
    }
    Assert-GeneratedNaming -Scenario $scenario -OutputPath $outputPath

    $packageProjectPath = Join-Path $outputPath "src/$($scenario.ExpectedShortName)/$($scenario.ExpectedShortName).csproj"
    $originalProject = Get-Content -Path $packageProjectPath -Raw
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $assemblyName = $packageProject.SelectSingleNode("/Project/PropertyGroup/AssemblyName")
    $null = $assemblyName.ParentNode.RemoveChild($assemblyName)
    $packageProject.Save($packageProjectPath)

    Assert-BuildFailsWithNamingError `
        -OutputPath $outputPath `
        -SolutionName $scenario.ExpectedShortName `
        -ExpectedError "AssemblyName '$($scenario.ExpectedShortName)' must equal PackageId '$($scenario.ExpectedPackageId)'" `
        -Description "Generated project without explicit AssemblyName"

    [System.IO.File]::WriteAllText($packageProjectPath, $originalProject)
    [xml]$packageProject = Get-Content -Path $packageProjectPath
    $packageProject.SelectSingleNode("/Project/PropertyGroup/PackageId").InnerText = "ContosoExample"
    $packageProject.Save($packageProjectPath)

    Assert-BuildFailsWithNamingError `
        -OutputPath $outputPath `
        -SolutionName $scenario.ExpectedShortName `
        -ExpectedError "PackageId 'ContosoExample' is invalid." `
        -Description "Generated project with invalid PackageId"

    Write-Host "[NamingGuards] Passed." -ForegroundColor Green
}

$baselinePackageId = Get-NormalizedPackageId -Name $PackageName
$baselineShortName = Get-ShortName -Name $PackageName
$scenarios = @(
    @{
        Name = "Baseline"
        InputName = $PackageName
        ExpectedPackageId = $baselinePackageId
        ExpectedShortName = $baselineShortName
        Arguments = @()
        ExpectBenchmarks = $true
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "Prefixed"
        InputName = $baselinePackageId
        ExpectedPackageId = $baselinePackageId
        ExpectedShortName = $baselineShortName
        Arguments = @()
        ExpectBenchmarks = $true
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "NoBenchmarks"
        InputName = "Contoso.NoBenchmarks"
        ExpectedPackageId = "Atya.Contoso.NoBenchmarks"
        ExpectedShortName = "NoBenchmarks"
        Arguments = @("--include-benchmarks", "false")
        ExpectBenchmarks = $false
        ExpectGitHub = $true
        RunLifecycle = $true
    },
    @{
        Name = "NoGitHub"
        InputName = "Contoso.NoGitHub"
        ExpectedPackageId = "Atya.Contoso.NoGitHub"
        ExpectedShortName = "NoGitHub"
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
    New-Item -ItemType Directory -Path $scratchRoot | Out-Null

    Write-Host "`nInstalling template from $repoRoot..." -ForegroundColor Yellow
    Invoke-NativeCommand -Description "Template installation" -Command {
        dotnet new install "$repoRoot" --force --debug:custom-hive $templateHive | Out-Null
    }

    $scenarioOutputs = @{}
    foreach ($scenario in $scenarios) {
        $scenarioOutputs[$scenario.Name] = Invoke-SmokeScenario -Scenario $scenario
    }

    Assert-EquivalentGeneratedOutput `
        -UnprefixedPath $scenarioOutputs.Baseline `
        -PrefixedPath $scenarioOutputs.Prefixed
    Write-Host "[Idempotence] Prefixed and unprefixed output matched." -ForegroundColor Green

    Assert-NamingGuardsFailFirstBuild

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
