# Atya NuGet Package Template

`Atya.Templates.NuGetPackage` is the source repository for the
`atya-nuget` .NET template.

## Create a package repository

```bash
dotnet new install Atya.Templates.NuGetPackage
dotnet new atya-nuget \
  --name Contoso.Example4 \
  --output Atya.Contoso.Example4
```

`--name Atya.Contoso.Example4` produces the same result. The generated public
identity is `Atya.Contoso.Example4`; local artifacts use the short name
`Example4`.

```text
Example4.sln
src/Example4/Example4.csproj
tests/Example4.UnitTests/
samples/Example4.Samples.Console/
benchmarks/Example4.Benchmarks/
```

The library project explicitly sets `PackageId`, `AssemblyName`, and
`RootNamespace` to the full public identity. C# namespaces and the default
repository URL also use that identity. Tests, samples, benchmarks, project
paths, and workflow paths use the short name.

Areas are controlled vocabulary. The initial approved values are `Foundation`,
`Governance`, and `Templates`; adding an area requires a deliberate naming
decision. Additional PascalCase segments may identify companion packages such
as `.Analyzers` or `.Abstractions`.

## Template source layout

The source repository dogfoods the same model:

```text
NuGetPackage.sln
src/NuGetPackage/NuGetPackage.csproj
tests/NuGetPackage.UnitTests/
samples/NuGetPackage.Samples.Console/
benchmarks/NuGetPackage.Benchmarks/
```

Its public identity remains `Atya.Templates.NuGetPackage`.

## Verify changes

```powershell
dotnet restore ./NuGetPackage.sln --locked-mode -p:RestoreLockedMode=true
dotnet format ./NuGetPackage.sln --verify-no-changes --no-restore
dotnet build ./NuGetPackage.sln --configuration Release --no-restore
dotnet test ./tests/NuGetPackage.UnitTests/NuGetPackage.UnitTests.csproj --configuration Release --no-build
pwsh ./template-smoke-test.ps1
```

The smoke test verifies both accepted name forms, short artifact paths, full
package identity, option variants, package contents, token replacement, and
naming guard failures.
