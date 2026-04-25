🚀 GitHub Actions Runner & Azure Pipelines Agent (Unraid)
Run a self-hosted GitHub Actions Runner and/or an Azure Pipelines Agent on Unraid using a single container.

✨ Features
Supports GitHub Actions and Azure DevOps Pipelines
Run one or both platforms in the same container
PowerShell (pwsh) preinstalled
Automatic agent updates (always latest)
Persistent configuration (no re-registration on restart)
Optional Docker build support
Designed for Unraid (AppData-based storage)
🧠 How it works
On startup, the container:

Checks which platforms are enabled
Downloads or reuses the latest runner binaries
Registers the runner/agent
Starts listening for jobs
All runtime data is stored in:

/mnt/user/appdata/github-actions-runner-azure-pipelines-agent

⚡ Quick Start
GitHub only
USE_GITHUB = true
GITHUB_URL = https://github.com/your-org/your-repo 
GITHUB_PAT = <your token>

Azure DevOps only
USE_AZDO = true
AZP_URL = https://dev.azure.com/your-org
AZP_TOKEN = <your token>

Both platforms
USE_GITHUB = true
USE_AZDO = true

🐙 GitHub Setup
You need a Personal Access Token (PAT).

Repository runner
Required permission:

Repository → Administration (Read & Write)
Organization runner
Required permission:

Organization → Self-hosted runners (Read & Write)
🔷 Azure DevOps Setup
You need a Personal Access Token (PAT).

Required permission:

Agent Pools → Read & manage
🐳 Docker Build Support
Disabled by default.

Enable it:
ENABLE_DOCKER = true
Extra Parameters: --restart unless-stopped --privileged

What this does
Starts a Docker daemon inside the container
Allows pipelines to build Docker images
Example:

docker build -t test .
docker run test

🔐 Security Notes
Default mode is safe.

If Docker is enabled:

Container runs in privileged mode
Only enable Docker if needed.

⚙️ Environment Variables
Core
USE_GITHUB → Enable GitHub runner
USE_AZDO → Enable Azure agent
ENABLE_DOCKER → Enable Docker inside container
GitHub
GITHUB_SCOPE → repo / org
GITHUB_URL → Repository URL
GITHUB_ORG → Organization name
GITHUB_PAT → Personal Access Token
GITHUB_RUNNER_NAME → Runner name
GITHUB_RUNNER_LABELS → Labels
Azure DevOps
AZP_URL → Organization URL
AZP_TOKEN → Personal Access Token
AZP_POOL → Agent pool
AZP_AGENT_NAME → Agent name
🔧 Troubleshooting
Runner not appearing
docker logs -f <container>

Docker not working
Ensure:

ENABLE_DOCKER=true
--privileged

Permission errors
Ensure AppData path is writable.

🔄 Updating
docker pull pavlospapalexiou/github-actions-runner-azure-pipelines-agent:latest

Restart container.

📚 Additional Documentation
See:

docs/permissions.md

❤️ Contributing
Pull requests welcome.

📄 License
MIT