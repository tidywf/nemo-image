# nemo-image

Docker image bundling [nemo], [tidywigits] and [tidydragen], so a single container
can run either workflow via the `nemo` CLI:

```shell
docker run --rm -v "$PWD:/work" -w /work ghcr.io/tidywf/nemo-image:<version> \
  tidy --workflow wigits -d inputs/wigits/ -o outputs/tidywigits

docker run --rm -v "$PWD:/work" -w /work ghcr.io/tidywf/nemo-image:<version> \
  tidy --workflow dragen -d inputs/dragen/ -o /outputs/tidydragen
```

The image bakes in a conda env that pins specific already-released versions of
[r-nemo], [r-tidywigits] and [r-tidydragen] from the [tidywf anaconda channel].
The bundled versions are recorded as OCI labels
(`io.tidywf.{nemo,tidywigits,tidydragen}.version`):

```shell
docker inspect --format '{{json .Config.Labels}}' ghcr.io/tidywf/nemo-image:<version>
```

## Files

| File | Purpose |
| ---- | ------- |
| `Dockerfile` | Two-stage build: `condaforge/miniforge3` builder creates the env from the lockfile, then only the env is copied into a slim `quay.io/bioconda/base-glibc-debian-bash` image. Entrypoint is `nemo.R`. |
| `nemo-image-env.yaml` | Pins the `r-nemo` / `r-tidywigits` / `r-tidydragen` versions this image bundles. Bumped by hand. |
| `lock-env.yaml` | Env CI uses to run `conda-lock`. |
| `scripts/pin-msg.sh` | Generates a commit message from the pin changes. |
| `.github/workflows/deploy.yaml` | On a `vX.Y.Z(.9XXX)` tag push: locks `nemo-image-env.yaml`, publishes the lockfiles as release assets, then builds and pushes the image via the reusable `tidywf/actions` `dockerise.yaml`. |

## Releasing

The git tag is the image version, independent of nemo/tidywigits/tidydragen's
own versions. Only `vX.Y.Z` and `vX.Y.Z.9XXX` tags trigger a build (the 4-part
dev form is published as a GitHub pre-release); pushing to `main` builds nothing.

```shell
# 1. Bump the r-* pins, then commit. Every CI job checks out the tag, so the
#    bump must be in the commit the tag points at.
git add nemo-image-env.yaml
git commit -F <(scripts/pin-msg.sh)   # or write your own message
git push

# 2. Tag and push the tag. This is the only thing that triggers deploy.yaml.
git tag v0.1.0
git push origin v0.1.0

# 3. Watch the run.
gh run watch
```

### Redoing a botched tag

Delete the tag locally and remotely, plus the GitHub Release it created
(`gh release create --verify-tag` won't overwrite a release whose tag has
moved), then re-tag:

```shell
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
gh release delete v0.1.0 --yes
```

### Commit message helper

`scripts/pin-msg.sh` diffs the working-tree pins against the last committed
ones and prints, for example:

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

Lockfiles aren't committed, so generate them into the repo root first (or
`gh release download vX.Y.Z` an existing release's assets and strip the
`nemo-image-vX.Y.Z-` prefix):

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
