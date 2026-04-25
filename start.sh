#!/usr/bin/env bash
set -euo pipefail

USE_AZDO="${USE_AZDO:-false}"
USE_GITHUB="${USE_GITHUB:-false}"
ENABLE_DOCKER="${ENABLE_DOCKER:-false}"

if [ "$USE_AZDO" != "true" ] && [ "$USE_GITHUB" != "true" ]; then
  echo "Nothing to start. Set USE_AZDO=true and/or USE_GITHUB=true."
  exit 1
fi

start_embedded_docker_if_enabled() {
  if [ "$ENABLE_DOCKER" != "true" ]; then
    echo "Embedded Docker is disabled. Set ENABLE_DOCKER=true to enable Docker builds."
    return
  fi

  if [ "${EMBEDDED_DOCKER_STARTED:-false}" = "true" ]; then
    echo "Embedded Docker already started."
    return
  fi

  echo "Starting embedded Docker daemon..."

  rm -f /var/run/docker.pid
  mkdir -p /runner-data/docker /runner-data/docker-exec

  dockerd \
    --host=unix:///var/run/docker.sock \
    --data-root=/runner-data/docker \
    --exec-root=/runner-data/docker-exec \
    ${DOCKER_OPTS:-} \
    > /tmp/dockerd.log 2>&1 &

  for i in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
      chmod 666 /var/run/docker.sock || true
      echo "Embedded Docker daemon is ready."
      docker --version
      return
    fi
    sleep 1
  done

  echo "Embedded Docker failed to start. Logs:"
  cat /tmp/dockerd.log || true
  exit 1
}

if [ "$(id -u)" = "0" ]; then
  mkdir -p /runner-data
  chown -R runner:runner /runner-data /runner /opt/azdo-agent /opt/github-runner

  if [ "$ENABLE_DOCKER" = "true" ]; then
    start_embedded_docker_if_enabled
    export EMBEDDED_DOCKER_STARTED=true
  fi

  echo "Fixing permissions and dropping to runner user..."
  exec su -m -s /bin/bash runner -c "/runner/start.sh"
fi

copy_agent_if_needed() {
  local source_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir"

  if [ ! -f "$target_dir/config.sh" ]; then
    echo "Copying agent files to $target_dir..."
    cp -a "$source_dir/." "$target_dir/"
  fi
}

resolve_latest_azdo_version() {
  curl -fsSL "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest" \
    | jq -r '.tag_name' \
    | sed 's/^v//'
}

resolve_latest_github_version() {
  curl -fsSL "https://api.github.com/repos/actions/runner/releases/latest" \
    | jq -r '.tag_name' \
    | sed 's/^v//'
}

ensure_latest_azdo_agent() {
  local target_dir="$1"
  local baked_version
  local latest_version
  local current_version

  baked_version="$(cat /opt/azdo-agent/.version 2>/dev/null || echo unknown)"
  current_version="$(cat "$target_dir/.version" 2>/dev/null || echo "$baked_version")"

  echo "Azure DevOps agent baked version: $baked_version"
  echo "Azure DevOps agent current version: $current_version"

  latest_version="$(resolve_latest_azdo_version)"
  echo "Azure DevOps agent latest version: $latest_version"

  if [ "$current_version" = "$latest_version" ] && [ -f "$target_dir/config.sh" ]; then
    echo "Azure DevOps agent already latest. Skipping download."
    return
  fi

  if [ "$baked_version" = "$latest_version" ] && [ -f /opt/azdo-agent/config.sh ]; then
    echo "Baked Azure DevOps agent is latest. Copying baked files."
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -a /opt/azdo-agent/. "$target_dir/"
    echo "$baked_version" > "$target_dir/.version"
    return
  fi

  echo "Downloading latest Azure DevOps agent $latest_version..."
  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  curl -fsSL \
    "https://download.agent.dev.azure.com/agent/${latest_version}/vsts-agent-linux-x64-${latest_version}.tar.gz" \
    -o /tmp/azdo-agent.tar.gz

  tar -xzf /tmp/azdo-agent.tar.gz -C "$target_dir"
  rm /tmp/azdo-agent.tar.gz
  echo "$latest_version" > "$target_dir/.version"
}

ensure_latest_github_runner() {
  local target_dir="$1"
  local baked_version
  local latest_version
  local current_version

  baked_version="$(cat /opt/github-runner/.version 2>/dev/null || echo unknown)"
  current_version="$(cat "$target_dir/.version" 2>/dev/null || echo "$baked_version")"

  echo "GitHub runner baked version: $baked_version"
  echo "GitHub runner current version: $current_version"

  latest_version="$(resolve_latest_github_version)"
  echo "GitHub runner latest version: $latest_version"

  if [ "$current_version" = "$latest_version" ] && [ -f "$target_dir/config.sh" ]; then
    echo "GitHub runner already latest. Skipping download."
    return
  fi

  if [ "$baked_version" = "$latest_version" ] && [ -f /opt/github-runner/config.sh ]; then
    echo "Baked GitHub runner is latest. Copying baked files."
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -a /opt/github-runner/. "$target_dir/"
    echo "$baked_version" > "$target_dir/.version"
    return
  fi

  echo "Downloading latest GitHub runner $latest_version..."
  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  curl -fsSL \
    "https://github.com/actions/runner/releases/download/v${latest_version}/actions-runner-linux-x64-${latest_version}.tar.gz" \
    -o /tmp/github-runner.tar.gz

  tar -xzf /tmp/github-runner.tar.gz -C "$target_dir"
  rm /tmp/github-runner.tar.gz
  echo "$latest_version" > "$target_dir/.version"
}

run_azdo() {
  if [ -z "${AZP_URL:-}" ]; then echo "USE_AZDO=true but AZP_URL is missing."; exit 1; fi
  if [ -z "${AZP_TOKEN:-}" ]; then echo "USE_AZDO=true but AZP_TOKEN is missing."; exit 1; fi

  AZP_POOL="${AZP_POOL:-SelfHosted}"
  AZP_AGENT_NAME="${AZP_AGENT_NAME:-unraid-azure-pipelines-agent}"
  AZP_WORK="${AZP_WORK:-_work}"

  mkdir -p /runner-data/azdo
  cd /runner-data/azdo

  copy_agent_if_needed /opt/azdo-agent /runner-data/azdo
  ensure_latest_azdo_agent /runner-data/azdo
  cd /runner-data/azdo

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
    if [ -z "${GITHUB_URL:-}" ]; then echo "USE_GITHUB=true but GITHUB_URL is missing."; exit 1; fi
    REG_URL="$GITHUB_URL"
  elif [ "$GITHUB_SCOPE" = "org" ]; then
    if [ -z "${GITHUB_ORG:-}" ]; then echo "USE_GITHUB=true but GITHUB_ORG is missing."; exit 1; fi
    REG_URL="https://github.com/${GITHUB_ORG}"
  else
    echo "Invalid GITHUB_SCOPE: $GITHUB_SCOPE. Use: repo or org."
    exit 1
  fi

  if [ -z "${GITHUB_PAT:-}" ] && [ -z "${GITHUB_RUNNER_TOKEN:-}" ]; then
    echo "USE_GITHUB=true but neither GITHUB_PAT nor GITHUB_RUNNER_TOKEN is set."
    exit 1
  fi

  GITHUB_RUNNER_NAME="${GITHUB_RUNNER_NAME:-unraid-github-actions-runner}"
  GITHUB_RUNNER_LABELS="${GITHUB_RUNNER_LABELS:-SelfHosted}"
  GITHUB_WORK="${GITHUB_WORK:-_work}"

  mkdir -p /runner-data/github
  cd /runner-data/github

  copy_agent_if_needed /opt/github-runner /runner-data/github
  ensure_latest_github_runner /runner-data/github
  cd /runner-data/github

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

start_embedded_docker_if_enabled

if [ "$USE_AZDO" = "true" ] && [ "$USE_GITHUB" = "true" ]; then
  run_azdo &
  AZDO_PID=$!

  run_github &
  GITHUB_PID=$!

  wait "$AZDO_PID" "$GITHUB_PID"
elif [ "$USE_AZDO" = "true" ]; then
  run_azdo
elif [ "$USE_GITHUB" = "true" ]; then
  run_github
fi