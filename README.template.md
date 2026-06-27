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
|-- .github/workflows/                        # Optional
`-- Directory.Packages.props
```

## Package naming

This repository uses two related names:

- `FULL_ID = Atya.Templates.NuGetPackage` is the public identity used by
  `PackageId`, `AssemblyName`, `RootNamespace`, C# namespaces, NuGet metadata,
  the package README title, and the repository URL.
- `SHORT = NuGetPackage` is the local artifact name used by the solution,
  project files, folders, project references, workflow paths, and test assembly
  name.

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
| `includeGitHub` | `true` | Includes CI, dependency review, tag-publish dispatch, and Renovate configuration. |

Every generated repository references `Atya.Foundation.Guards` at runtime and
uses `Atya.Build.Sdk` for shared build, analyzer, versioning, SourceLink, and
test-stack wiring. These baseline choices cannot be disabled with template
options.

All generated projects target `net10.0` through `Atya.Build.Sdk`.

## Development

```bash
dotnet restore
dotnet format --verify-no-changes
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
dotnet pack ./src/NuGetPackage/NuGetPackage.csproj \
  --configuration Release \
  --no-build \
  --output artifacts/packages
```

The first restore creates fresh `packages.lock.json` files for every generated
project. CI then restores in locked mode.

CI audits NuGet dependencies, restores in locked mode, verifies formatting,
builds on Linux and Windows, publishes TRX results, enforces 80% line coverage,
validates the package, and uploads symbols. Dependency Review runs on pull
requests through the organization reusable workflow.

`Atya.Build.Sdk` enables package validation for packable projects. After the
first stable NuGet release, set `PackageValidationBaselineVersion` to the last
stable version and bump it after each later stable release.

## GitHub setup

When `includeGitHub=true`, create the repository with `development` as the
default branch and set the `atya-managed=true` custom property so the
organization rulesets apply. Short-lived branches merge into `development`
through pull requests with the required `ci / *` checks. Only `development`
opens release pull requests to `master`; that promotion uses a merge commit so
the long-lived branches retain shared ancestry.

Generated repositories publish without per-repository NuGet API keys. Pushing a
`vMAJOR.MINOR.PATCH` tag runs `publish-nuget.yml`, which dispatches a
`publish-package` request to `AtyaLibraries/publisher`. The central publisher is
the only NuGet.org publishing chokepoint and owns trusted publishing, signing,
and NuGet.org release credentials.

Do not add NuGet.org API-key secrets to generated repositories. The only
repository-side publish dependency is access to the organization dispatch
credential used by `publish-nuget.yml`.

## Versioning and releases

MinVer derives package versions from `vMAJOR.MINOR.PATCH` tags. Release by
merging `development` to `master` with a merge commit, then pushing the stable
version tag. The generated publish workflow is tag-only and dispatches the
central publisher; it does not pack or push to NuGet.org directly.
