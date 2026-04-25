#!/usr/bin/env bash
set -euo pipefail

RUNNER_MODE="${RUNNER_MODE:-${RUNNER_TYPE:-}}"

if [ -z "$RUNNER_MODE" ]; then
  echo "Missing RUNNER_MODE. Use: azdo, github, or both."
  exit 1
fi

run_azdo() {
  if [ -z "${AZP_URL:-}" ]; then echo "Missing AZP_URL"; exit 1; fi
  if [ -z "${AZP_TOKEN:-}" ]; then echo "Missing AZP_TOKEN"; exit 1; fi

  AZP_POOL="${AZP_POOL:-Default}"
  AZP_AGENT_NAME="${AZP_AGENT_NAME:-$(hostname)-azdo}"
  AZP_WORK="${AZP_WORK:-_work}"

  mkdir -p /runner/azdo
  cd /runner/azdo

  if [ ! -f ./config.sh ]; then
    echo "Downloading Azure DevOps agent ${AZP_AGENT_VERSION}..."
    curl -fsSL \
        "https://download.agent.dev.azure.com/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz" \
        -o agent.tar.gz
    tar -xzf agent.tar.gz
    rm agent.tar.gz
  fi

  if [ -f ".agent" ]; then
    echo "Azure DevOps agent already configured. Reusing existing configuration."
  else
    echo "Configuring Azure DevOps agent..."

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
  fi

  echo "Azure DevOps agent starting..."
  ./run.sh
}

get_github_runner_token() {
  if [ -n "${GITHUB_RUNNER_TOKEN:-}" ]; then
    echo "$GITHUB_RUNNER_TOKEN"
    return
  fi

  if [ -z "${GITHUB_PAT:-}" ]; then
    echo "Missing GITHUB_PAT or GITHUB_RUNNER_TOKEN" >&2
    exit 1
  fi

  GITHUB_SCOPE="${GITHUB_SCOPE:-repo}"

  if [ "$GITHUB_SCOPE" = "repo" ]; then
    if [ -z "${GITHUB_URL:-}" ]; then echo "Missing GITHUB_URL" >&2; exit 1; fi

    OWNER_REPO="$(echo "$GITHUB_URL" | sed -E 's#https://github.com/##' | sed -E 's#/$##')"

    curl -fsSL -X POST \
      -H "Authorization: Bearer ${GITHUB_PAT}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${OWNER_REPO}/actions/runners/registration-token" \
      | jq -r .token

  elif [ "$GITHUB_SCOPE" = "org" ]; then
    if [ -z "${GITHUB_ORG:-}" ]; then echo "Missing GITHUB_ORG" >&2; exit 1; fi

    curl -fsSL -X POST \
      -H "Authorization: Bearer ${GITHUB_PAT}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token" \
      | jq -r .token

  else
    echo "Invalid GITHUB_SCOPE: $GITHUB_SCOPE. Use: repo or org." >&2
    exit 1
  fi
}

run_github() {
  GITHUB_SCOPE="${GITHUB_SCOPE:-repo}"

  if [ "$GITHUB_SCOPE" = "repo" ]; then
    if [ -z "${GITHUB_URL:-}" ]; then echo "Missing GITHUB_URL"; exit 1; fi
    REG_URL="$GITHUB_URL"
  elif [ "$GITHUB_SCOPE" = "org" ]; then
    if [ -z "${GITHUB_ORG:-}" ]; then echo "Missing GITHUB_ORG"; exit 1; fi
    REG_URL="https://github.com/${GITHUB_ORG}"
  else
    echo "Invalid GITHUB_SCOPE: $GITHUB_SCOPE. Use: repo or org."
    exit 1
  fi

  GITHUB_RUNNER_NAME="${GITHUB_RUNNER_NAME:-$(hostname)-github}"
  GITHUB_RUNNER_LABELS="${GITHUB_RUNNER_LABELS:-unraid,linux,pwsh}"
  GITHUB_WORK="${GITHUB_WORK:-_work}"

  mkdir -p /runner/github
  cd /runner/github

  if [ ! -f ./config.sh ]; then
    echo "Downloading GitHub Actions runner ${GITHUB_RUNNER_VERSION}..."
    curl -fsSL \
      "https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz" \
      -o actions-runner.tar.gz
    tar -xzf actions-runner.tar.gz
    rm actions-runner.tar.gz
  fi

  if [ -f ".runner" ]; then
    echo "GitHub runner already configured. Reusing existing configuration."
  else
    echo "Requesting GitHub runner registration token..."
    RUNNER_TOKEN="$(get_github_runner_token)"

    if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
      echo "Failed to obtain GitHub runner registration token."
      exit 1
    fi

    echo "Configuring GitHub runner..."

    ./config.sh \
      --unattended \
      --url "$REG_URL" \
      --token "$RUNNER_TOKEN" \
      --name "$GITHUB_RUNNER_NAME" \
      --labels "$GITHUB_RUNNER_LABELS" \
      --work "$GITHUB_WORK" \
      --replace
  fi

  echo "GitHub runner starting..."
  ./run.sh
}

case "$RUNNER_MODE" in
  azdo)
    run_azdo
    ;;
  github)
    run_github
    ;;
  both)
    run_azdo &
    AZDO_PID=$!

    run_github &
    GITHUB_PID=$!

    wait $AZDO_PID $GITHUB_PID
    ;;
  *)
    echo "Invalid RUNNER_MODE: $RUNNER_MODE. Use: azdo, github, or both."
    exit 1
    ;;
esac