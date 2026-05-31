TODO: Add a 128x128 icon.png before publishing a polished template package.

# Atya.Templates.AbnpPackage

Production-ready .NET 10 NuGet package starter.

## Install

```bash
dotnet new install Atya.Templates.AbnpPackage
```

## Use

```bash
dotnet new abnp-package --name Atya.YourPackage
```

You get a ready-to-build package repository with source, tests, samples, optional benchmarks, central package management, GitHub CI, NuGet publishing, Dependabot, and release-note metadata already in place.

## What's Included

- `src/`, `tests/`, `samples/`, and optional `benchmarks/` projects targeting `net10.0`.
- CI workflow for restore, audit, format, build, test, coverage, and pack.
- Publish workflow for tagged stable NuGet releases.
- Dependabot and central package management.
- `Atya.Foundation.Guards`, `Atya.Governance.CodeQuality`, and `Atya.Governance.Testing` pre-wired.

## First-Time Setup

After creating and pushing the generated repository, run `./bootstrap.ps1` to apply GitHub repository defaults, branch protection, labels, and the optional `NUGET_API_KEY` secret.

## License

MIT. See the [template repository](https://github.com/AtyaLibraries/Atya.Templates.AbnpPackage).
