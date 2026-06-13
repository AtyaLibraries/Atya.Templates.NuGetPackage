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
|-- NuGetPackage.sln
|-- src/NuGetPackage/NuGetPackage.csproj
|-- tests/NuGetPackage.UnitTests/
|-- samples/NuGetPackage.Samples.Console/
|-- benchmarks/NuGetPackage.Benchmarks/       # Optional
|-- docs/RELEASING.md
|-- .github/                                  # Optional
`-- Directory.Packages.props
```

## Package naming

This repository uses two related names:

- `FULL_ID = Atya.Templates.NuGetPackage` is the public identity used by
  `PackageId`, `AssemblyName`, `RootNamespace`, C# namespaces, NuGet metadata,
  the package README title, and the repository URL.
- `SHORT = NuGetPackage` is the local artifact name used by the solution,
  project files, folders, project references, workflow paths, and test friend
  assembly name.

The template accepts either `--name Foundation.Caching` or
`--name Atya.Foundation.Caching`. Both produce `FULL_ID =
Atya.Foundation.Caching` and `SHORT = Caching`.

Use `{Area}.{Name}` after the optional `Atya.` prefix. Areas are controlled
vocabulary; the initial approved values are `Foundation`, `Governance`, and
`Templates`. Adding an area requires a deliberate repository-wide naming
decision. Companion suffixes such as `.Analyzers` or `.Abstractions` remain
valid.

The build fails packable projects whose `PackageId` is invalid or whose
`AssemblyName` or `RootNamespace` differs from `PackageId`. Set
`SkipPackageNamingValidation=true` only for an explicit exception.

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
dotnet pack ./src/NuGetPackage/NuGetPackage.csproj \
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
