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
  ./template-smoke-test.ps1 -KeepOutput
#>
[CmdletBinding()]
param(
    [string]$PackageName = "Atya.SmokeTest.Pkg",

    [switch]$KeepOutput
)

$ErrorActionPreference = "Stop"
$templateRoot  = $PSScriptRoot
$repoRoot      = Resolve-Path $templateRoot
$scratch       = Join-Path ([System.IO.Path]::GetTempPath()) "atya-nuget-smoke-$([guid]::NewGuid().ToString('N').Substring(0,8))"
$generatedRoot = Join-Path $scratch $PackageName

Write-Host "Template root: $templateRoot" -ForegroundColor Cyan
Write-Host "Repo root    : $repoRoot" -ForegroundColor Cyan
Write-Host "Scratch dir  : $scratch" -ForegroundColor Cyan

try {
    Write-Host "`n[1/5] Installing template from $repoRoot..." -ForegroundColor Yellow
    dotnet new install "$repoRoot" --force | Out-Null

    Write-Host "`n[2/5] Generating package '$PackageName' into $scratch..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $scratch | Out-Null
    Push-Location $scratch
    try {
        dotnet new atya-nuget --name $PackageName
    }
    finally {
        Pop-Location
    }

    Write-Host "`n[3/5] Verifying no unresolved template placeholders remain..." -ForegroundColor Yellow
    $placeholderMatches = Get-ChildItem -Path $generatedRoot -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|artifacts)\\' } |
        Select-String -Pattern '__[A-Z_]+__|Atya\.Templates\.NuGetPackage|atya-nuget'

    if ($placeholderMatches) {
        $details = $placeholderMatches | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" }
        throw "Template placeholders remain in generated output:`n$($details -join "`n")"
    }

    [xml]$packageProject = Get-Content -Path (Join-Path $generatedRoot "src\$PackageName\$PackageName.csproj")
    $packageId = $packageProject.SelectSingleNode("/Project/PropertyGroup/PackageId").InnerText.Trim()

    if ($packageId -ne $PackageName) {
        throw "Expected PackageId '$PackageName', found '$packageId'."
    }

    [xml]$buildProps = Get-Content -Path (Join-Path $generatedRoot "Directory.Build.props")
    $repositoryUrl = $buildProps.SelectSingleNode("/Project/PropertyGroup/RepositoryUrl").InnerText.Trim()
    $expectedRepositoryUrl = "https://github.com/AtyaLibraries/$PackageName"

    if ($repositoryUrl -ne $expectedRepositoryUrl) {
        throw "Expected RepositoryUrl '$expectedRepositoryUrl', found '$repositoryUrl'."
    }

    Write-Host "`n[4/5] Building and testing generated repository..." -ForegroundColor Yellow
    Push-Location $generatedRoot
    try {
        dotnet restore ".\$PackageName.sln" --verbosity minimal
        dotnet build ".\$PackageName.sln" --configuration Release --no-restore --verbosity minimal
        dotnet test ".\tests\$PackageName.UnitTests\$PackageName.UnitTests.csproj" --configuration Release --no-build --verbosity minimal
    }
    finally {
        Pop-Location
    }

    Write-Host "`n[5/5] Packing generated repository..." -ForegroundColor Yellow
    Push-Location $generatedRoot
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
        Write-Host "Generated repository kept at: $generatedRoot" -ForegroundColor DarkGray
    }
}
