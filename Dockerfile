FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG AZP_AGENT_VERSION=latest
ARG GITHUB_RUNNER_VERSION=latest
ARG NODE_MAJOR=24
ARG BWS_VERSION=1.0.0

ENV AZP_AGENT_VERSION=${AZP_AGENT_VERSION}
ENV GITHUB_RUNNER_VERSION=${GITHUB_RUNNER_VERSION}
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

RUN apt-get update && apt-get install -y --no-install-recommends rsync \
    ca-certificates sudo curl wget git jq unzip tar gzip openssh-client  \
    apt-transport-https gnupg software-properties-common \
    libicu70 libssl3 libkrb5-3 zlib1g \
    fuse-overlayfs slirp4netns uidmap iptables dbus-user-session \
    build-essential \
    python3 python3-pip pkg-config postgresql-client libpq-dev shellcheck \
    && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/* \
    && pwsh --version

# Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /ms-playwright \
    && npx -y playwright@1.62.0 install --with-deps chromium \
    && chmod -R 0755 /ms-playwright

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Bitwarden Secrets Manager CLI
RUN set -eux; \
    curl -fsSL \
      "https://github.com/bitwarden/sdk/releases/download/bws-v${BWS_VERSION}/bws-x86_64-unknown-linux-gnu-${BWS_VERSION}.zip" \
      -o /tmp/bws.zip; \
    unzip /tmp/bws.zip -d /tmp/bws; \
    install -m 0755 "$(find /tmp/bws -type f -name bws | head -n1)" /usr/local/bin/bws; \
    rm -rf /tmp/bws /tmp/bws.zip; \
    bws --version

RUN useradd -m -u 1000 -s /bin/bash runner

WORKDIR /runner

RUN mkdir -p /opt/azdo-agent /opt/github-runner /runner-data

RUN set -eux; \
    if [ "$AZP_AGENT_VERSION" = "latest" ]; then \
      AZP_RESOLVED_VERSION="$(curl -fsSL https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name' | sed 's/^v//')"; \
    else \
      AZP_RESOLVED_VERSION="$AZP_AGENT_VERSION"; \
    fi; \
    echo "$AZP_RESOLVED_VERSION" > /opt/azdo-agent/.version; \
    curl -fsSL \
      "https://download.agent.dev.azure.com/agent/${AZP_RESOLVED_VERSION}/vsts-agent-linux-x64-${AZP_RESOLVED_VERSION}.tar.gz" \
      -o /tmp/azdo-agent.tar.gz; \
    tar -xzf /tmp/azdo-agent.tar.gz -C /opt/azdo-agent; \
    rm /tmp/azdo-agent.tar.gz

RUN set -eux; \
    if [ "$GITHUB_RUNNER_VERSION" = "latest" ]; then \
      GITHUB_RESOLVED_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')"; \
    else \
      GITHUB_RESOLVED_VERSION="$GITHUB_RUNNER_VERSION"; \
    fi; \
    echo "$GITHUB_RESOLVED_VERSION" > /opt/github-runner/.version; \
    curl -fsSL \
      "https://github.com/actions/runner/releases/download/v${GITHUB_RESOLVED_VERSION}/actions-runner-linux-x64-${GITHUB_RESOLVED_VERSION}.tar.gz" \
      -o /tmp/github-runner.tar.gz; \
    tar -xzf /tmp/github-runner.tar.gz -C /opt/github-runner; \
    rm /tmp/github-runner.tar.gz

RUN git --version \
    && node --version \
    && npm --version \
    && npx --version \
    && gh --version \
    && bws --version \
    && psql --version \
    && jq --version \
    && rsync --version \
    && ssh -V \
    && docker --version \
    && pwsh --version

COPY start.sh /runner/start.sh

RUN sed -i 's/\r$//' /runner/start.sh \
    && chmod +x /runner/start.sh \
    && chown -R runner:runner /runner /runner-data /opt/azdo-agent /opt/github-runner

USER root

ENTRYPOINT ["/runner/start.sh"]