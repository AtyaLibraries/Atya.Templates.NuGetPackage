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

## Package naming

Packable projects use `Atya.{Area}.{Name}`. The template accepts either
`--name Contoso.Example` or `--name Atya.Contoso.Example` and normalizes both
inputs to `Atya.Contoso.Example` for package, assembly, namespace, solution,
project, folder, workflow, and repository names.

Use two segments after the optional prefix when creating a repository:
`{Area}.{Name}`. Areas are controlled vocabulary; the initial approved values
are `Foundation`, `Governance`, and `Templates`. Adding an area requires a
deliberate repository-wide naming decision rather than an ad-hoc invention.
Companion package suffixes such as `.Analyzers` or `.Abstractions` remain valid.

The build fails packable projects whose `PackageId` does not follow the
convention. Set `SkipPackageNamingValidation=true` only for an explicit
exception.

## Template options

| Symbol | Default | Result |
| --- | --- | --- |
| `includeBenchmarks` | `true` | Includes the benchmark project. |
| `includeGitHub` | `true` | Includes `.github/` and `bootstrap.ps1`. |

Every generated repository includes `Atya.Foundation.Guards`,
`Atya.Governance.CodeQuality`, and `Atya.Governance.Testing`. These packages
are part of the template baseline and cannot be disabled with template options.

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

The first restore creates fresh `packages.lock.json` files for every generated
project. CI then restores in locked mode.

CI audits dependencies, restores in locked mode, verifies formatting, builds on
Linux and Windows, publishes TRX results, enforces 80% line coverage, validates
the package, and uploads symbols.

## GitHub setup

When `includeGitHub=true`, push `development` and `master`, authenticate the
GitHub CLI, and run:

```powershell
./bootstrap.ps1 -RepoOwner __GITHUB_OWNER__ -RepoName Atya.Templates.NuGetPackage
```

The script idempotently creates active, no-bypass rulesets for both branches.
Short-lived branches merge into `development` through squash-only pull requests
with linear history and green Linux and Windows CI checks. Only `development`
can open a release pull request to `master`; that promotion uses a merge commit
so the long-lived branches retain shared ancestry. Force pushes, branch
deletion, and direct pushes are blocked on both branches.

The default rulesets require no external approval so a solo maintainer can
merge after CI passes and review threads are resolved. Increase the approval
count or enable CODEOWNER review when another maintainer is available.

Set these repository values before publishing:

- Secret `NUGET_API_KEY`
- Secret `NUGET_SIGN_CERT_BASE64`
- Secret `NUGET_SIGN_CERT_PASSWORD`
- Variable `REQUIRE_SIGNED_PACKAGES` (defaults to `true`; set `false` only for an explicit unsigned-publishing exception)

## Versioning and releases

MinVer derives package versions from `vMAJOR.MINOR.PATCH` tags. The publish
workflow supports an explicit stable SemVer input for a controlled manual
release. See `docs/RELEASING.md` for the complete publish and recovery process.
