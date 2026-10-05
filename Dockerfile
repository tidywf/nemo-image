# Builder only needs conda to materialise the env from the lockfile; only the
# env dir is copied into the final image.
# Pinned by multi-arch index digest; bump together with MINIF_VERSION.
ARG MINIF_VERSION="26.7.2-0"
ARG MINIF_DIGEST="sha256:569afc65b5338d35e276adf9a860025cd37a677659d19dcb71fc1d4c2063a94e"
FROM condaforge/miniforge3:${MINIF_VERSION}@${MINIF_DIGEST} AS builder

# set by docker buildx
ARG TARGETARCH
# Env is created at the exact prefix the final stage uses: conda envs are not
# relocatable (prefixes get baked into scripts/shebangs at install time).
ARG CONDA_ENV_PREFIX="/opt/miniforge/envs/nemo_env"
ARG CONDA_ENV_DIR="/home/conda_envs"
# Lockfiles are not committed; they are fetched into the repo root at build
# time. CI (deploy.yaml) generates and publishes them as release assets, and
# dockerise.yaml downloads them. For a local build, see README.md.
COPY "./conda-linux-64.lock" "./conda-linux-aarch64.lock" "${CONDA_ENV_DIR}/"
RUN case "${TARGETARCH}" in \
      amd64) LOCKFILE="conda-linux-64.lock" ;; \
      arm64) LOCKFILE="conda-linux-aarch64.lock" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    conda create -p "${CONDA_ENV_PREFIX}" --file "${CONDA_ENV_DIR}/${LOCKFILE}"

# Now copy env to smaller image
FROM quay.io/bioconda/base-glibc-debian-bash:3.1

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
