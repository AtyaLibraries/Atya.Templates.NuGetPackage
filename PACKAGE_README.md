# Atya NuGet Package Template

`Atya.Templates.NuGetPackage` scaffolds a production-ready .NET library
repository with central package management, MinVer, SourceLink, tests, samples,
optional benchmarks, reproducible restores, package validation, and hardened
GitHub workflows.

## Install

```bash
dotnet new install Atya.Templates.NuGetPackage
```

## Create a repository

```bash
dotnet new atya-nuget --name Contoso.Example
```

The generated repository targets `net10.0`, includes GitHub automation and benchmarks,
and has no runtime or analyzer dependency on first-party Atya packages.

## Template options

| Option | Default | Behavior |
| --- | --- | --- |
| `--include-benchmarks` | `true` | Includes the BenchmarkDotNet project and solution wiring. |
| `--include-github` | `true` | Includes GitHub workflows, issue templates, CODEOWNERS, Dependabot, and `bootstrap.ps1`. |
| `--include-atya-guards` | `false` | Adds the `Atya.Foundation.Guards` runtime dependency and wiring test. |
| `--include-atya-governance` | `false` | Uses `Atya.Governance.CodeQuality` and `Atya.Governance.Testing`. |

When Atya governance is disabled, the generated repository uses
`Microsoft.CodeAnalysis.NetAnalyzers`, `StyleCop.Analyzers`, and
`Microsoft.VisualStudio.Threading.Analyzers`.

```bash
dotnet new atya-nuget \
  --name Contoso.Example \
  --include-benchmarks false \
  --include-atya-guards false \
  --include-atya-governance false
```

## Generated safeguards

- NuGet auditing at `low` severity or higher and lock-file enforcement in CI.
- Formatting, build, xUnit tests, TRX reporting, and an 80% line coverage gate.
- Package validation, symbols, SourceLink, SBOM generation, and provenance attestation.
- Signed publishing by default when GitHub publishing is enabled.
- Rulesets-based protection for `development` and `master`.

The template includes a neutral package icon. Replace
`src/<PackageName>/icon.png` with the final 128x128 package artwork before the
first public release.

## Versioning

MinVer derives versions from `vMAJOR.MINOR.PATCH` tags. Generated repositories
also support an explicit stable SemVer override through the Publish NuGet
workflow dispatch input.
