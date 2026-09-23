FROM ubuntu:24.04 AS builder

ARG MINIF="miniforge"
ARG MINIF_VERSION="26.7.2-0"
# Miniforge installer SHA256 per arch (from the release *.sh.sha256 assets).
# Bump these together with MINIF_VERSION.
ARG MINIF_SHA_AMD64="281b0ac7d550802efc81af633225a5e6116d29ae72f3ab4eae7168c3931a4c05"
ARG MINIF_SHA_ARM64="89b786c8d2c8b0fda7553914c1314ae4ddaa094503802f279377b19ac4463cb2"
# set by docker buildx
ARG TARGETARCH

# install core pkgs, miniforge
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    bash bzip2 curl less wget zip ca-certificates && \
    apt-get clean && \
    case "${TARGETARCH}" in \
      amd64) MINIF_ARCH="x86_64" ; MINIF_SHA="${MINIF_SHA_AMD64}" ;; \
      arm64) MINIF_ARCH="aarch64" ; MINIF_SHA="${MINIF_SHA_ARM64}" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl --silent -L \
      "https://github.com/conda-forge/${MINIF}/releases/download/${MINIF_VERSION}/Miniforge3-${MINIF_VERSION}-Linux-${MINIF_ARCH}.sh" \
      -o "${MINIF}.sh" && \
    echo "${MINIF_SHA}  ${MINIF}.sh" | sha256sum --check --status && \
    /bin/bash "${MINIF}.sh" -b -p "/opt/${MINIF}/" && \
    rm "${MINIF}.sh"

# create conda env
ENV PATH="/opt/${MINIF}/bin:$PATH"
ARG CONDA_ENV_DIR="/home/conda_envs"
# Lockfiles are not committed; they are fetched into the repo root at build
# time. CI (deploy.yaml) generates and publishes them as release assets. For a
# local build first run, from the repo root:
#   conda-lock lock --file nemo-image-env.yaml \
#     --channel tidywf/label/dev --channel tidywf --channel conda-forge \
#     -p linux-64 -p linux-aarch64
#   for p in linux-64 linux-aarch64; do
#     conda-lock render -p ${p} conda-lock.yml && mv conda-${p}.lock .; done
COPY "./conda-linux-64.lock" "./conda-linux-aarch64.lock" "${CONDA_ENV_DIR}/"
RUN case "${TARGETARCH}" in \
      amd64) LOCKFILE="conda-linux-64.lock" ;; \
      arm64) LOCKFILE="conda-linux-aarch64.lock" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    conda create -n "nemo_env" --file "${CONDA_ENV_DIR}/${LOCKFILE}"
RUN conda clean --all --force-pkgs-dirs --yes

# Now copy env to smaller image
FROM quay.io/bioconda/base-glibc-debian-bash:3.1

# Which r-* versions this image bundles. The image tag is nemo-image's own
# version (see .github/workflows/deploy.yaml), so the bundled component
# versions are recorded here as labels instead of being encoded in the tag:
#   docker inspect --format '{{json .Config.Labels}}' ghcr.io/tidywf/nemo-image:X.Y.Z
# CI passes these as --build-arg, parsed from nemo-image-env.yaml.
# Left empty for ad-hoc local builds.
ARG NEMO_VERSION=""
ARG TIDYWIGITS_VERSION=""
ARG TIDYDRAGEN_VERSION=""

LABEL org.opencontainers.image.authors="peterdiakumis@gmail.com" \
      org.opencontainers.image.description="bundled nemo + tidywigits + tidydragen" \
      org.opencontainers.image.source="https://github.com/tidywf/nemo-image" \
      org.opencontainers.image.url="https://github.com/tidywf/nemo-image" \
      org.opencontainers.image.licenses="MIT" \
      io.tidywf.nemo.version="${NEMO_VERSION}" \
      io.tidywf.tidywigits.version="${TIDYWIGITS_VERSION}" \
      io.tidywf.tidydragen.version="${TIDYDRAGEN_VERSION}"

COPY --from=builder "/opt/miniforge/envs/" "/opt/miniforge/envs/"

# env is activated by default
ARG MINIF="miniforge"
ARG CONDA_ENV_NAME="nemo_env"
ENV PATH="/opt/${MINIF}/envs/${CONDA_ENV_NAME}/bin:${PATH}"
ENV CONDA_PREFIX="/opt/${MINIF}/envs/${CONDA_ENV_NAME}"

# nemo.R is the fixed executable; args passed to `docker run`/compose append
# as its subcommand + flags (e.g. `tidy --workflow wigits ...`).
# Override with --entrypoint for a raw shell.
ENTRYPOINT [ "nemo.R" ]
CMD [ "--help" ]
