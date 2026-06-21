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
| `includeGitHub` | `true` | Includes GitHub workflows, release metadata, and Renovate configuration. |

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

CI audits dependencies, restores in locked mode, verifies formatting, builds on
Linux and Windows, publishes TRX results, enforces 80% line coverage, validates
the package, and uploads symbols.

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

Set these repository values before publishing:

- Secret `NUGET_API_KEY`
- Secret `NUGET_SIGN_CERT_BASE64`
- Secret `NUGET_SIGN_CERT_PASSWORD`
- Variable `REQUIRE_SIGNED_PACKAGES` (defaults to `true`; set `false` only for an explicit unsigned-publishing exception)

## Versioning and releases

MinVer derives package versions from `vMAJOR.MINOR.PATCH` tags. The publish
workflow supports an explicit stable SemVer input for a controlled manual
release. See `docs/RELEASING.md` for the complete publish and recovery process.
