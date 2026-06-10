# Contributing

## Development setup

Install the SDK version from `global.json`, clone the repository, and run:

```bash
dotnet restore --use-lock-file
dotnet format --verify-no-changes
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
```

The first restore creates fresh `packages.lock.json` files for every project.
Commit those files so local and CI restores resolve the same dependency graph.

Run benchmarks only from a Release build:

```bash
dotnet run --configuration Release --project ./benchmarks/Atya.Templates.NuGetPackage.Benchmarks/Atya.Templates.NuGetPackage.Benchmarks.csproj
```

## Branching model

Create short-lived branches from `development` and open pull requests back to
`development`. Release pull requests promote `development` to `master`.
Protected branches require signed commits, linear history, review, and all
required CI checks.

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/),
for example `feat: add parser support` or `fix: reject invalid input`. Keep each
commit focused and include breaking-change footers when applicable.

If the repository requires the Developer Certificate of Origin, sign each
commit message with:

```text
Signed-off-by: Your Name <you@example.com>
```

Use `git commit -s` to add the line automatically.

## Pull request checklist

- Run `dotnet format --verify-no-changes`.
- Run the Release build and all tests.
- Keep line coverage at or above 80%.
- Add or update tests for behavior changes.
- Update `CHANGELOG.md` for user-visible changes.
- Confirm package metadata and documentation remain accurate.

## Release flow

Use Conventional Commits and update `CHANGELOG.md` during normal development.
Promote `development` to `master` through a reviewed pull request. The merge
starts the publish workflow, which derives the next version with MinVer and
creates the tag and GitHub Release after NuGet publishing succeeds.

For an explicit version, run the `Publish NuGet` workflow manually and provide a
stable `MAJOR.MINOR.PATCH` value. Follow `docs/RELEASING.md` for signing,
verification, and failed-publish recovery.

## Security issues

Do not file public issues for vulnerabilities. Follow `SECURITY.md` and use the
[private security advisory form](https://github.com/__GITHUB_OWNER__/Atya.Templates.NuGetPackage/security/advisories/new).
