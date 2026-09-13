FROM alpine:3.20

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN apk add --no-cache openssh-server=10.3_p1-r1 openssh-client=10.3_p1-r1 sudo=1.9.17_p2-r1

# Create testuser
RUN adduser -D -s /bin/ash testuser && \
    echo 'testuser:testuser' | chpasswd && \
    echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Setup SSH
RUN mkdir -p /home/testuser/.ssh && \
    chmod 700 /home/testuser/.ssh && \
    chown testuser:testuser /home/testuser/.ssh

# Copy authorized_keys
COPY authorized_keys /home/testuser/.ssh/authorized_keys
RUN chmod 600 /home/testuser/.ssh/authorized_keys && \
    chown testuser:testuser /home/testuser/.ssh/authorized_keys

# Configure sshd
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#StrictModes yes/StrictModes no/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Generate host keys
RUN ssh-keygen -A

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
