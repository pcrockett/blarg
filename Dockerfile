ARG PYTHON_VERSION=3.14

# intentionally using older bookworm, since python trixie doesn't go lower than 3.10
FROM docker.io/library/python:${PYTHON_VERSION}-slim-bookworm
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]
ARG DEBIAN_FRONTEND=noninteractive

# don't need to pin apt package versions
# hadolint ignore=DL3008
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
rm -f /etc/apt/apt.conf.d/docker-clean && \
apt-get update && \
apt-get install --yes --no-install-recommends curl ca-certificates git make extrepo && \
extrepo enable mise && \
apt-get update && \
apt-get install --yes --no-install-recommends mise && \
useradd --create-home user && \
mkdir /app && \
chown -R user:user /app

USER user
WORKDIR /app

ENV HOME=/home/user
ENV PATH="${HOME}/.local/bin:${PATH}"

COPY --chown=user:user mise.toml mise.lock ./
RUN \
mise trust && \
mise use uv@0.12.2 && \
mise install

ENTRYPOINT [ "mise", "exec", "--" ]
CMD [ "make", "test" ]
