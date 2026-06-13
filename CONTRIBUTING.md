# Contributing

## Development setup

Install the SDK version from `global.json`, clone the repository, and run:

```bash
dotnet restore
dotnet format --verify-no-changes
dotnet build --configuration Release --no-restore
dotnet test --configuration Release --no-build
```

The first restore creates fresh `packages.lock.json` files for every project.
Commit those files so local and CI restores resolve the same dependency graph.

Run benchmarks only from a Release build:

```bash
dotnet run --configuration Release --project ./benchmarks/NuGetPackage.Benchmarks/NuGetPackage.Benchmarks.csproj
```

## Package naming

Packable projects use a full public identity and a short local name. For
`--name Contoso.Example4` or `--name Atya.Contoso.Example4`, the public
`PackageId`, `AssemblyName`, `RootNamespace`, and namespaces are
`Atya.Contoso.Example4`, while solution, project, folder, workflow, and
non-shipping assembly names use `Example4`.

The public ID must use `Atya.{Area}.{Name}` with PascalCase segments.
Additional segments are allowed for companion packages such as `.Analyzers`
and `.Abstractions`. Packable projects must keep `AssemblyName` and
`RootNamespace` equal to `PackageId`.

The controlled Area vocabulary starts with `Foundation`, `Governance`, and
`Templates`. New areas require a deliberate naming decision and documentation
update; do not introduce areas ad hoc.

## Branching model

Create short-lived branches from `development` and open pull requests back to
`development`; those pull requests use squash merges. Release pull requests
must promote `development` to `master` and use merge commits to preserve shared
history between the long-lived branches. Direct pushes, force pushes, and
deletion are blocked on both protected branches, and required CI checks must
pass before merge.

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
Promote `development` to `master` through a pull request after all release
candidates are accepted and CI is green. The branch-policy check rejects any
other source branch. The merge starts the publish workflow, which derives the
next version with MinVer and creates the tag and GitHub Release after NuGet
publishing succeeds.

For an explicit version, run the `Publish NuGet` workflow manually and provide a
stable `MAJOR.MINOR.PATCH` value. Follow `docs/RELEASING.md` for signing,
verification, and failed-publish recovery.

## Security issues

Do not file public issues for vulnerabilities. Follow `SECURITY.md` and use the
[private security advisory form](https://github.com/__GITHUB_OWNER__/Atya.Templates.NuGetPackage/security/advisories/new).
