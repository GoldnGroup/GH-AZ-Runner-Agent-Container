#!/usr/bin/env bash
set -euo pipefail

RUNNER_TYPE="${RUNNER_TYPE:-}"

if [ -z "$RUNNER_TYPE" ]; then
  echo "Missing RUNNER_TYPE. Use 'azdo' or 'github'."
  exit 1
fi

run_azdo() {
  if [ -z "${AZP_URL:-}" ]; then echo "Missing AZP_URL"; exit 1; fi
  if [ -z "${AZP_TOKEN:-}" ]; then echo "Missing AZP_TOKEN"; exit 1; fi

  AZP_POOL="${AZP_POOL:-Default}"
  AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)}"
  AZP_WORK="${AZP_WORK:-_work}"

  mkdir -p /runner/azdo
  cd /runner/azdo

  cleanup() {
    echo "Removing Azure DevOps agent registration..."
    if [ -f ./config.sh ]; then
      ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" || true
    fi
  }

  trap cleanup EXIT

  if [ ! -f ./config.sh ]; then
    echo "Downloading Azure DevOps agent ${AZP_AGENT_VERSION}..."
    curl -fsSL \
      "https://vstsagentpackage.azureedge.net/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz" \
      -o agent.tar.gz

    tar -xzf agent.tar.gz
    rm agent.tar.gz
  fi

  ./config.sh \
    --unattended \
    --url "$AZP_URL" \
    --auth pat \
    --token "$AZP_TOKEN" \
    --pool "$AZP_POOL" \
    --agent "$AZP_AGENT_NAME" \
    --work "$AZP_WORK" \
    --acceptTeeEula \
    --replace

  echo "Azure DevOps agent configured. Starting..."
  exec ./run.sh
}

run_github() {
  if [ -z "${GITHUB_URL:-}" ]; then echo "Missing GITHUB_URL"; exit 1; fi
  if [ -z "${GITHUB_TOKEN:-}" ]; then echo "Missing GITHUB_TOKEN"; exit 1; fi

  GITHUB_RUNNER_NAME="${GITHUB_RUNNER_NAME:-$(hostname)}"
  GITHUB_RUNNER_LABELS="${GITHUB_RUNNER_LABELS:-self-hosted,linux,unraid}"
  GITHUB_WORK="${GITHUB_WORK:-_work}"

  mkdir -p /runner/github
  cd /runner/github

  cleanup() {
    echo "Removing GitHub runner registration..."
    if [ -f ./config.sh ]; then
      ./config.sh remove --unattended --token "$GITHUB_TOKEN" || true
    fi
  }

  trap cleanup EXIT

  if [ ! -f ./config.sh ]; then
    echo "Downloading GitHub Actions runner ${GITHUB_RUNNER_VERSION}..."
    curl -fsSL \
      "https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz" \
      -o actions-runner.tar.gz

    tar -xzf actions-runner.tar.gz
    rm actions-runner.tar.gz
  fi

  ./config.sh \
    --unattended \
    --url "$GITHUB_URL" \
    --token "$GITHUB_TOKEN" \
    --name "$GITHUB_RUNNER_NAME" \
    --labels "$GITHUB_RUNNER_LABELS" \
    --work "$GITHUB_WORK" \
    --replace

  echo "GitHub runner configured. Starting..."
  exec ./run.sh
}

case "$RUNNER_TYPE" in
  azdo)
    run_azdo
    ;;
  github)
    run_github
    ;;
  *)
    echo "Invalid RUNNER_TYPE: $RUNNER_TYPE. Use 'azdo' or 'github'."
    exit 1
    ;;
esac