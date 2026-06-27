# Atya NuGet Package Template

`Atya.Templates.NuGetPackage` scaffolds a production-ready .NET library
repository with central package management, Atya.Build.Sdk-backed MinVer and
SourceLink wiring, tests, samples, optional benchmarks, reproducible restores,
package validation, and hardened GitHub workflows.

## Install

```bash
dotnet new install Atya.Templates.NuGetPackage
```

## Create a repository

```bash
dotnet new atya-nuget \
  --name Foundation.Caching \
  --output Atya.Foundation.Caching
```

The template accepts `{Area}.{Name}` and `Atya.{Area}.{Name}` input forms.
Both normalize idempotently. For the example above:

- `FULL_ID = Atya.Foundation.Caching` is used for the package ID, assembly,
  root namespace, C# namespaces, metadata, README title, and repository URL.
- `SHORT = Caching` is used for the solution, local projects and folders,
  project references, workflow paths, and non-shipping assembly names.

The generated layout starts with `Caching.sln`,
`src/Caching/Caching.csproj`, `tests/Caching.UnitTests/`,
`samples/Caching.Samples.Console/`, and
`benchmarks/Caching.Benchmarks/`.

Areas are controlled vocabulary. The initial approved values are `Foundation`,
`Governance`, and `Templates`; adding another area requires a deliberate
naming decision rather than an ad-hoc invention.

Pass the normalized repository name to `--output` when creating a new
directory. The .NET template host chooses its automatic output directory from
the raw `--name` value before template value transforms run.

The generated repository targets `net10.0`, includes GitHub automation and
benchmarks, references the Atya Guards runtime package, and uses
`Atya.Build.Sdk` for shared build, analyzer, versioning, SourceLink, and
test-stack wiring.

## Template options

| Option | Default | Behavior |
| --- | --- | --- |
| `--include-benchmarks` | `true` | Includes the BenchmarkDotNet project and solution wiring. |
| `--include-github` | `true` | Includes CI, dependency review, tag-publish dispatch, and Renovate configuration. |

`Atya.Foundation.Guards` is the unconditional runtime baseline. `Atya.Build.Sdk`
supplies the shared CodeQuality, Testing, MinVer, and SourceLink wiring. These
baseline choices are not controlled by template options.

```bash
dotnet new atya-nuget \
  --name Atya.Foundation.Caching \
  --output Atya.Foundation.Caching \
  --include-benchmarks false
```

## Generated safeguards

- NuGet auditing at `low` severity or higher and lock-file enforcement in CI.
- Formatting, build, xUnit tests, TRX reporting, and an 80% line coverage gate.
- Package validation, symbols, SourceLink, SBOM generation, and provenance attestation.
- A build and pack guard that rejects nonconforming package IDs and requires
  `AssemblyName` and `RootNamespace` to equal `PackageId`, unless
  `SkipPackageNamingValidation=true` is set for an explicit exception.
- Keyless tag-based publishing through the central `AtyaLibraries/publisher`
  workflow.
- Rulesets-based protection for `development` and `master`.

## Versioning

MinVer derives versions from `vMAJOR.MINOR.PATCH` tags. Generated repositories
publish without repo-local NuGet API keys: pushing a `v*` tag dispatches the
central publisher, which owns NuGet.org trusted publishing and release
credentials.
