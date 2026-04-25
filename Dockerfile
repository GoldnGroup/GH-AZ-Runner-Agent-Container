FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG AZP_AGENT_VERSION=latest
ARG GITHUB_RUNNER_VERSION=latest

ENV AZP_AGENT_VERSION=${AZP_AGENT_VERSION}
ENV GITHUB_RUNNER_VERSION=${GITHUB_RUNNER_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git jq unzip tar gzip \
    apt-transport-https gnupg software-properties-common \
    libicu70 libssl3 libkrb5-3 zlib1g \
    docker.io \
    docker-buildx \
    fuse-overlayfs \
    slirp4netns \
    uidmap \
    iptables \
    dbus-user-session \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/* \
    && pwsh --version

RUN useradd -m -u 1000 -s /bin/bash runner

RUN echo "runner:100000:65536" >> /etc/subuid \
    && echo "runner:100000:65536" >> /etc/subgid

WORKDIR /runner

RUN mkdir -p /opt/azdo-agent /opt/github-runner

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

COPY start.sh /runner/start.sh

COPY start.sh /runner/start.sh

RUN sed -i 's/\r$//' /runner/start.sh \
    && chmod +x /runner/start.sh \
    && mkdir -p /runner-data \
    && chown -R runner:runner /runner /runner-data /opt/azdo-agent /opt/github-runner

USER runner

ENTRYPOINT ["/runner/start.sh"]