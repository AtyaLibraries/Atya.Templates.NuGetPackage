# __PACKAGE_NAME__

__PACKAGE_DESCRIPTION__

| | |
| --- | --- |
| Repository | [__REPOSITORY_URL__](__REPOSITORY_URL__) |
| NuGet | `__PACKAGE_NAME__` |
| License | MIT |

## Layout

```text
.
|-- src/__PACKAGE_NAME__/                          # The shipped library
|-- tests/__PACKAGE_NAME__.UnitTests/              # Starter unit test project
|-- samples/__PACKAGE_NAME__.Samples.Console/      # Starter sample app
|-- benchmarks/__PACKAGE_NAME__.Benchmarks/        # Optional BenchmarkDotNet project
`-- .github/                                       # Optional CI/release config
```

## Starter Content

The generated library project is intentionally minimal so you can add the real
package implementation without first removing fake public APIs.

Replace the starter tests, sample, benchmarks, and README sections with
package-specific content before shipping the package.

## Build, test, pack

```bash
dotnet restore
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
dotnet pack ./src/__PACKAGE_NAME__/__PACKAGE_NAME__.csproj --configuration Release --no-build --output artifacts/packages
```

Artifacts land in `artifacts/packages/`.

## Versioning

Versions are derived from git tags via [MinVer](https://github.com/adamralph/minver).
Merges to `master` publish stable NuGet packages through
`.github/workflows/publish-nuget.yml`, which creates the version tag and GitHub
Release after a successful publish.

```bash
# Optional manual workflow version override:
1.2.0
```
