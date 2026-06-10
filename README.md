# Atya.Templates.NuGetPackage

__PACKAGE_DESCRIPTION__

| | |
| --- | --- |
| Repository | [__REPOSITORY_URL__](__REPOSITORY_URL__) |
| NuGet | `Atya.Templates.NuGetPackage` |
| License | MIT |

## Layout

```text
.
|-- src/Atya.Templates.NuGetPackage/                      # Shipped library
|-- tests/Atya.Templates.NuGetPackage.UnitTests/          # xUnit tests
|-- samples/Atya.Templates.NuGetPackage.Samples.Console/  # Sample application
|-- benchmarks/Atya.Templates.NuGetPackage.Benchmarks/    # Optional benchmarks
|-- docs/RELEASING.md                              # Release and recovery flow
|-- .github/                                       # Optional GitHub automation
|-- bootstrap.ps1                                  # Optional repository setup
`-- Directory.Packages.props                       # Central package versions
```

## Template options

| Symbol | Default | Result |
| --- | --- | --- |
| `includeBenchmarks` | `true` | Includes the benchmark project. |
| `includeGitHub` | `true` | Includes `.github/` and `bootstrap.ps1`. |
| `includeAtyaGuards` | `false` | Adds `Atya.Foundation.Guards` and its wiring test. |
| `includeAtyaGovernance` | `false` | Uses Atya governance analyzer packages. |

With `includeAtyaGovernance=false`, analyzer coverage comes from
`Microsoft.CodeAnalysis.NetAnalyzers`, `StyleCop.Analyzers`, and
`Microsoft.VisualStudio.Threading.Analyzers`.

All generated projects target `net10.0`.

## Development

```bash
dotnet restore
dotnet format --verify-no-changes
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
dotnet pack ./src/Atya.Templates.NuGetPackage/Atya.Templates.NuGetPackage.csproj \
  --configuration Release \
  --no-build \
  --output artifacts/packages \
  -p:EnablePackageValidation=true
```

CI audits dependencies, restores in locked mode, verifies formatting, builds on
Linux and Windows, publishes TRX results, enforces 80% line coverage, validates
the package, and uploads symbols.

## GitHub setup

When `includeGitHub=true`, push `development` and `master`, authenticate the
GitHub CLI, and run:

```powershell
./bootstrap.ps1 -RepoOwner __GITHUB_OWNER__ -RepoName Atya.Templates.NuGetPackage
```

The script idempotently creates an active repository ruleset for both branches.
It applies to administrators, requires pull requests and CODEOWNER review,
requires signed commits and linear history, blocks force pushes and deletion,
and requires the Linux and Windows CI checks.

Set these repository values before publishing:

- Secret `NUGET_API_KEY`
- Secret `NUGET_SIGN_CERT_BASE64`
- Secret `NUGET_SIGN_CERT_PASSWORD`
- Variable `REQUIRE_SIGNED_PACKAGES` (defaults to `true`; set `false` only for an explicit unsigned-publishing exception)

## Versioning and releases

MinVer derives package versions from `vMAJOR.MINOR.PATCH` tags. The publish
workflow supports an explicit stable SemVer input for a controlled manual
release. See `docs/RELEASING.md` for the complete publish and recovery process.
