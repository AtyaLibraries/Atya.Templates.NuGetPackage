TODO: Add a 128x128 icon.png before publishing a polished template package.

# Atya.Templates.NuGetPackage

Production-ready .NET 10 NuGet package starter.

## Install

```bash
dotnet new install Atya.Templates.NuGetPackage
```

## Use

```bash
dotnet new atya-nuget --name Atya.YourPackage
```

You get a ready-to-build package repository with source, tests, samples, optional benchmarks, central package management, GitHub CI, NuGet publishing, Dependabot, and release-note metadata already in place.

## What's Included

- `src/`, `tests/`, `samples/`, and optional `benchmarks/` projects targeting `net10.0`.
- CI workflow for restore, audit, format, build, test, coverage, and pack.
- Publish workflow for tagged stable NuGet releases.
- Dependabot and central package management.
- `Atya.Foundation.Guards`, `Atya.Governance.CodeQuality`, and `Atya.Governance.Testing` pre-wired.

## Naming Convention

Future Atya templates should follow the same package and short-name shape:

```text
Atya.Templates.NuGetPackage     -> atya-nuget
Atya.Templates.ConsoleApp       -> atya-console
Atya.Templates.WorkerService    -> atya-worker
Atya.Templates.WebApi           -> atya-webapi
Atya.Templates.AnalyzerPackage  -> atya-analyzer
Atya.Templates.SourceGenerator  -> atya-generator
```

## First-Time Setup

After creating and pushing the generated repository, run `./bootstrap.ps1` to apply GitHub repository defaults, branch protection, labels, and the optional `NUGET_API_KEY` secret.

## License

MIT. See the [template repository](https://github.com/AtyaLibraries/Atya.Templates.NuGetPackage).
