# Atya.PackageTemplate

A reusable .NET package from Atya.

| | |
| --- | --- |
| Repository | [https://github.com/AtyaLibraries/Atya.PackageTemplate](https://github.com/AtyaLibraries/Atya.PackageTemplate) |
| NuGet | `Atya.PackageTemplate` |
| License | MIT |

## Layout

```text
.
|-- src/Atya.PackageTemplate/                      # The shipped library
|-- tests/Atya.PackageTemplate.UnitTests/          # Starter unit test project
|-- samples/Atya.PackageTemplate.Samples.Console/  # Starter sample app
|-- benchmarks/Atya.PackageTemplate.Benchmarks/    # BenchmarkDotNet project
`-- .github/                                       # CI/release configuration
```

## Starter Content

The generated library project is intentionally minimal so you can add the real
package implementation without first removing fake public APIs.

Replace the starter tests, sample, benchmarks, and README sections with
package-specific content before shipping the package.

## Build, test, pack

The package currently targets `net10.0`. CI restores, audits vulnerable
packages, checks formatting, builds, tests with coverage, enforces 80% line
coverage, packs with package validation, runs CodeQL, and publishes release
artifacts with an SBOM and build provenance attestation.

```bash
dotnet restore
dotnet format --verify-no-changes
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
dotnet pack ./src/Atya.PackageTemplate/Atya.PackageTemplate.csproj --configuration Release --no-build --output artifacts/packages -p:EnablePackageValidation=true
```

Artifacts land in `artifacts/packages/`.

## Versioning

Versions are derived from git tags via [MinVer](https://github.com/adamralph/minver).
Merges to `master` publish stable NuGet packages through
`.github/workflows/publish-nuget.yml`, which creates the version tag and GitHub
Release after a successful publish.

```bash
# Optional manual workflow version override:
1.2.0
```
