# Contributing

## Branching

Use `development` for active work. Open pull requests into `development`, then promote `development` to `master` when ready to publish. Merges to `master` trigger the NuGet publish workflow.

## Commit Style

Conventional Commits are suggested for readable history and release notes, but they are not enforced by the template.

## Local Build Commands

Use the restore, build, test, and pack commands documented in `README.md`.

## Benchmarks

When benchmarks are included, run:

```bash
dotnet run --configuration Release --project ./benchmarks/__PACKAGE_NAME__.Benchmarks/__PACKAGE_NAME__.Benchmarks.csproj
```
