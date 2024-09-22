ARG PYTHON_VERSION=3.12
FROM docker.io/library/python:${PYTHON_VERSION}-slim-bookworm
SHELL [ "/bin/bash", "-Eeuo", "pipefail", "-c" ]
ARG DEBIAN_FRONTEND=noninteractive

# don't need to pin apt package versions
# hadolint ignore=DL3008
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
rm -f /etc/apt/apt.conf.d/docker-clean && \
apt-get update && \
apt-get install --yes --no-install-recommends curl ca-certificates git make && \
useradd --create-home user && \
mkdir /app && \
chown -R user:user /app

USER user
WORKDIR /app

ENV HOME=/home/user
ENV ASDF_DIR="${HOME}/.asdf"
ENV PATH="${ASDF_DIR}/bin:${ASDF_DIR}/shims:${PATH}"

RUN \
curl -SsfL https://philcrockett.com/yolo/v1.sh | bash -s -- docker/asdf && \
. "${HOME}/.asdf/asdf.sh" && \
asdf plugin add bats https://github.com/pcrockett/asdf-bats.git

COPY --chown=user:user .tool-versions .

RUN asdf install

CMD [ "make", "test" ]
