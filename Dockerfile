FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV AZP_AGENT_VERSION=3.248.0
ENV GITHUB_RUNNER_VERSION=2.327.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git jq unzip tar gzip \
    apt-transport-https gnupg software-properties-common \
    libicu70 libssl3 libkrb5-3 zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/* \
    && pwsh --version

RUN useradd -m -u 1000 -s /bin/bash runner

WORKDIR /runner

COPY start.sh /runner/start.sh
RUN chmod +x /runner/start.sh && chown -R runner:runner /runner

USER runner

ENTRYPOINT ["/runner/start.sh"]