# 🔐 Permissions Guide

This document explains the required permissions for GitHub and Azure DevOps.

---

## 🐙 GitHub

The container uses a Personal Access Token (PAT) to register the runner.

---

### Repository Runner

Use when:

GITHUB_SCOPE = repo

Required permissions:

- Repository → Administration (Read & Write)

---

### Organization Runner

Use when:

GITHUB_SCOPE = org

Required permissions:

- Organization → Self-hosted runners (Read & Write)

---

### Token Type

Recommended:
- Fine-grained Personal Access Token

---

## 🔷 Azure DevOps

The container uses a Personal Access Token (PAT).

---

### Required permissions

- Agent Pools → Read & manage

---

### Scope

- Organization level

---

## ⚠️ Security Recommendations

- Do NOT use full admin tokens
- Limit scope to only required permissions
- Rotate tokens periodically
- Store tokens securely (Unraid masks them)

---

## 🧠 Notes

- The container only uses tokens for registration
- Jobs run inside the runner environment
- No credentials are stored outside /runner-data

---

## 🔒 Docker Mode

If Docker is enabled:

ENABLE_DOCKER=true
--privileged

Then:

- Container runs with elevated privileges
- Can build and run Docker images

Use only when needed.