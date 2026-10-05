# CLAUDE.md: nemo-image

Docker image repo. Bundles `nemo` + `tidywigits` + `tidydragen` into one
container so `nemo tidy --workflow {wigits,dragen} ...` works from a single
image. Ecosystem context: `tidywf/CLAUDE.md`.

## Why a separate repo

The three packages release independently. A composite image has its own
version axis (*which combination* is bundled), so pinning it to any one
repo's tag would force needless rebuilds or miss needed ones.

Prospective consumer: `nemo-infra`'s Lambda, which extends
`ghcr.io/tidywf/tidywigits` today and would switch to
`ghcr.io/tidywf/nemo-image` to dispatch either workflow via the `nemo` CLI.

## Structure

```
Dockerfile                     # miniforge3 image builder -> slim final, ENTRYPOINT nemo.R
nemo-image-env.yaml            # pins r-nemo / r-tidywigits / r-tidydragen
lock-env.yaml                  # conda-lock's own env, CI only
scripts/pin-msg.sh             # commit message from pin diff (dev convenience)
.github/workflows/deploy.yaml  # vX.Y.Z tag: conda-lock -> release assets -> dockerise
```

## Gotchas

- **Pins are the whole point.** The three `r-*` lines in
  `nemo-image-env.yaml` are hand-bumped; nothing tracks "latest". Check each
  package's released version (`DESCRIPTION` or the `tidywf` channel) first,
  then tag `vX.Y.Z(.9XXX)`. There's no `bump.yaml` here.
- **Dev pins need the dev channel.** `condarise.yaml` uploads 4-part versions
  (`x.y.z.9XXX`) under `--label dev`, so they are invisible on plain `tidywf`.
  `nemo-image-env.yaml` lists `tidywf/label/dev` first, and the lock job
  repeats all three channels on the `conda-lock` CLI (CLI channels override
  the ones in the env file, so both must agree).
- **Bundled versions ride as OCI labels, not in the tag.** The tag is this
  repo's own version; `deploy.yaml`'s `prep` job parses the pins and passes
  them as dockerise `labels:` → `io.tidywf.{nemo,tidywigits,tidydragen}.version`
  (no Dockerfile LABELs; local builds carry none).
  Inspect with `docker inspect --format '{{json .Config.Labels}}'`.
- **Builder is `condaforge/miniforge3`**, pinned by multi-arch index digest
  (`MINIF_DIGEST`); bump together with `MINIF_VERSION`. The env is created
  with `conda create -p` at the final-stage prefix (`/opt/miniforge/envs/nemo_env`)
  since conda envs are not relocatable. Mirrors `tidywigits/Dockerfile`.
- **Lockfiles aren't committed.** CI generates them and attaches them to the
  Release; the Dockerfile `COPY`s them from the build context root (local
  build command is in the Dockerfile comment).
