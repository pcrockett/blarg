# it's ok to use :latest
# hadolint ignore=DL3007
FROM alpine:latest

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# don't pin package versions
# hadolint ignore=DL3018
RUN apk add --no-cache openssh-server openssh-client sudo python3 bash

ARG TEST_USER="testuser"
RUN \
adduser -D -s /bin/ash "${TEST_USER}" && \
echo "${TEST_USER}:${TEST_USER}" | chpasswd && \
echo "${TEST_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
mkdir -p "/home/${TEST_USER}/.ssh" && \
chmod 700 "/home/${TEST_USER}/.ssh" && \
chown "${TEST_USER}:${TEST_USER}" "/home/${TEST_USER}/.ssh"

COPY test_key.pub /home/${TEST_USER}/.ssh/authorized_keys
RUN \
chmod 600 "/home/${TEST_USER}/.ssh/authorized_keys" && \
chown "${TEST_USER}:${TEST_USER}" "/home/${TEST_USER}/.ssh/authorized_keys" && \
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
sed -i 's/#StrictModes yes/StrictModes no/' /etc/ssh/sshd_config && \
ssh-keygen -A

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
