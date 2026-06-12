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
dotnet new atya-nuget \
  --name Contoso.Example \
  --output Atya.Contoso.Example
```

The template accepts `{Area}.{Name}` and `Atya.{Area}.{Name}` input forms.
Both normalize idempotently to `Atya.{Area}.{Name}`. Use two segments after
the optional prefix for the default package; additional PascalCase segments
are reserved for companion packages such as `.Analyzers` or `.Abstractions`.

Areas are controlled vocabulary. The initial approved values are `Foundation`,
`Governance`, and `Templates`; adding another area requires a deliberate
naming decision rather than an ad-hoc invention. `Contoso.Example` is an
illustrative input and should be replaced with the approved area and package
name.

Pass the normalized repository name to `--output` when creating a new
directory. The .NET template host chooses its automatic output directory from
the raw `--name` value before template value transforms run.

The generated repository targets `net10.0`, includes GitHub automation and
benchmarks, and uses the Atya Guards, CodeQuality, and Testing packages by
default.

## Template options

| Option | Default | Behavior |
| --- | --- | --- |
| `--include-benchmarks` | `true` | Includes the BenchmarkDotNet project and solution wiring. |
| `--include-github` | `true` | Includes GitHub workflows, issue templates, CODEOWNERS, Dependabot, and `bootstrap.ps1`. |

`Atya.Foundation.Guards`, `Atya.Governance.CodeQuality`, and
`Atya.Governance.Testing` are unconditional baseline dependencies and are not
controlled by template options.

```bash
dotnet new atya-nuget \
  --name Contoso.Example \
  --output Atya.Contoso.Example \
  --include-benchmarks false
```

## Generated safeguards

- NuGet auditing at `low` severity or higher and lock-file enforcement in CI.
- Formatting, build, xUnit tests, TRX reporting, and an 80% line coverage gate.
- Package validation, symbols, SourceLink, SBOM generation, and provenance attestation.
- A build and pack guard that rejects nonconforming package IDs unless
  `SkipPackageNamingValidation=true` is set for an explicit exception.
- Signed publishing by default when GitHub publishing is enabled.
- Rulesets-based protection for `development` and `master`.

The template includes a neutral package icon. Replace
`src/<PackageName>/icon.png` with the final 128x128 package artwork before the
first public release.

## Versioning

MinVer derives versions from `vMAJOR.MINOR.PATCH` tags. Generated repositories
also support an explicit stable SemVer override through the Publish NuGet
workflow dispatch input.
