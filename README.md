# nemo-image

Docker image bundling [nemo], [tidywigits] and [tidydragen], so a single container
can run either workflow via the `nemo` CLI:

```shell
docker run --rm -v "$PWD:/work" -w /work ghcr.io/tidywf/nemo-image:<version> \
  tidy --workflow wigits -d inputs/wigits/ -o outputs/tidywigits

docker run --rm -v "$PWD:/work" -w /work ghcr.io/tidywf/nemo-image:<version> \
  tidy --workflow dragen -d inputs/dragen/ -o /outputs/tidydragen
```

The conda env pins specific already-released versions of [r-nemo], [r-tidywigits] and
[r-tidydragen] (from the [tidywf anaconda channel]) and a Dockerfile that bakes
that env into an image.

## Files

- `Dockerfile`: two-stage build that installs miniforge + the pinned conda env in
  a builder stage, then copies just the env into a slim
  `quay.io/bioconda/base-glibc-debian-bash` final image. Entrypoint is `nemo.R`.
- `nemo-image-env.yaml`: pins the `r-nemo` / `r-tidywigits` / `r-tidydragen`
  versions this image bundles. Bump these by hand, then tag a release.
- `lock-env.yaml`: env used by CI to run `conda-lock`.
- `scripts/pin-msg.sh`: generates a commit message from the pin changes.
- `.github/workflows/deploy.yaml`: on a `vX.Y.Z(.9XXX)` tag push, locks
  `nemo-image-env.yaml` with `conda-lock`, publishes the lockfiles as release
  assets, then builds and pushes the image via the reusable
  `tidywf/actions/dockerise.yaml` workflow.

## Versioning

The git tag is the version, and it's independent of nemo/tidywigits/tidydragen's
own version numbers. To cut a release:

1. Bump the pinned versions in `nemo-image-env.yaml`
2. Commit, tag `vX.Y.Z`, push the tag, then `deploy.yaml` does the rest

```shell
# 1. bump the r-* pins, then commit. Every CI job checks out the tag, so the
#    bump must be in the commit the tag points at.
git add nemo-image-env.yaml
git commit -F <(scripts/pin-msg.sh)   # see below; or write your own message
git push

# 2. tag and push the tag. This is the only thing that triggers deploy.yaml.
git tag v0.1.0
git push origin v0.1.0
```

Only `vX.Y.Z` and `vX.Y.Z.9XXX` tags trigger a build; the 4-part dev form is
published as a GitHub pre-release. Pushing to `main` builds nothing.

Watch the run, then confirm what landed:

```shell
gh run watch
docker inspect --format '{{json .Config.Labels}}' ghcr.io/tidywf/nemo-image:0.1.0
```

To redo a botched tag, delete it locally and remotely (and delete the GitHub
Release it created, since `gh release create --verify-tag` won't overwrite a
release whose tag has moved), then re-tag:

```shell
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
gh release delete v0.1.0 --yes
```

`scripts/pin-msg.sh` builds that message from the yaml itself. It diffs the
working-tree pins against the last committed ones and prints, for example:

```
pin r-nemo 0.2.0, r-tidydragen 0.1.0

Bundled package versions:
  r-nemo 0.1.0.9004 -> 0.2.0
  r-tidywigits 0.1.0.9000 (unchanged)
  r-tidydragen 0.0.0.9002 -> 0.1.0
```

Only changed packages reach the subject line; all three are listed in the
body. It exits non-zero if nothing changed, so it will not produce an empty
bump commit. Run it bare to preview the message first.

## Local build

```shell
conda-lock lock --file nemo-image-env.yaml \
  --channel tidywf/label/dev --channel tidywf --channel conda-forge \
  -p linux-64 -p linux-aarch64
for p in linux-64 linux-aarch64; do
  conda-lock render -p ${p} conda-lock.yml && mv conda-${p}.lock .
done
rm conda-lock.yml

docker build --platform linux/amd64 -t nemo-image:local .
```

<!-- Reference-style links -->

[nemo]: https://github.com/tidywf/nemo
[tidywigits]: https://github.com/tidywf/tidywigits
[tidydragen]: https://github.com/tidywf/tidydragen
[r-nemo]: https://anaconda.org/channels/tidywf/packages/r-nemo/overview
[r-tidywigits]: https://anaconda.org/channels/tidywf/packages/r-tidywigits/overview
[r-tidydragen]: https://anaconda.org/channels/tidywf/packages/r-tidydragen/overview
[tidywf anaconda channel]: https://anaconda.org/channels/tidywf
