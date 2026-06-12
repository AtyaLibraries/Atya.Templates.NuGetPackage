# Releasing

## Generated package repository

1. Collect release candidates in `development`, then open a pull request from
   `development` to `master`. Other source branches are rejected.
2. The `Publish NuGet` workflow restores in locked mode, audits, formats,
   builds, tests, packs, generates an SBOM, and attests package provenance.
3. The workflow signs `.nupkg` files unless unsigned publishing was explicitly
   enabled with `REQUIRE_SIGNED_PACKAGES=false`.
4. After a successful NuGet push, the workflow creates the
   `vMAJOR.MINOR.PATCH` tag and GitHub Release.

When `master` already points at a stable version tag, MinVer uses that tag.
Otherwise the workflow increments the latest stable patch version.

## Manual version override

Run the `Publish NuGet` workflow with `workflow_dispatch` and set `version` to a
stable `MAJOR.MINOR.PATCH` value. The workflow rejects prerelease labels,
build metadata, and tags that already point at another commit.

Use the override for coordinated releases or intentional major/minor changes.
Do not edit project files to hardcode a package version.

## Template package

For the template repository itself, create and push a stable tag:

```bash
git tag -s v1.2.3 -m "v1.2.3"
git push origin v1.2.3
```

The `Publish Template` workflow smoke-tests the template, verifies
`PackageType=Template` in the packed nuspec, publishes the package, and creates
the GitHub Release.

## Failed publish recovery

- Before any package reaches nuget.org, fix the cause and rerun the same
  workflow/version.
- If only some artifacts were published, rerun the same version. NuGet pushes
  use `--skip-duplicate`, allowing the workflow to complete missing symbols,
  tags, attestations, or release assets.
- NuGet versions are immutable. If a bad package was published, unlist it on
  nuget.org, fix the defect, and publish a new patch version.
- Never move or reuse a tag for a version that reached nuget.org. Delete and
  recreate a tag only when no immutable package or public release exists for
  that version, then document the correction.
