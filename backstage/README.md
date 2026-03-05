# Backstage Portal (Local)

Docker Compose setup for a local Backstage developer portal using the [official Backstage image](https://github.com/backstage/backstage/pkgs/container/backstage%2Fbackstage).

## Features

- **Create Kafka Topic** – provisions a new Kafka topic. Duplicate names are blocked via catalog. Workflow run link shown for status polling.
- **Destroy Kafka Topic** – destroys a topic and removes it from the catalog.
- **Adjust Kafka Topic Partitions** – increases partitions for an existing topic (Kafka cannot decrease).

## Prerequisites

- Docker and Docker Compose
- GitHub Personal Access Token (PAT) to trigger `workflow_dispatch`:
  - **Classic PAT**: `repo` (or `public_repo`) + `workflow` scopes
  - **Fine-grained PAT**: Repository permission **Actions** → **Read and write** on `ba-playground`

## Quick Start

1. Add your GitHub token to `backstage/.env` (the file exists with a placeholder; add your token to `GITHUB_TOKEN=`).

2. Start the portal:

   ```bash
   docker compose up -d
   ```

3. Open http://localhost:7007

4. Go to **Create** → choose a template (Create Kafka Topic, Destroy Kafka Topic, or Adjust Partitions) → fill in parameters → **Create**. Use the workflow run link to poll for completion.

## Configuration

| Variable        | Default    | Description                    |
|----------------|------------|--------------------------------|
| `POSTGRES_USER`| backstage  | PostgreSQL user                |
| `POSTGRES_PASSWORD` | backstage | PostgreSQL password        |
| `POSTGRES_DB`  | backstage  | PostgreSQL database            |
| `GITHUB_TOKEN` | (required) | GitHub PAT for workflow dispatch |

## Template Parameters

- **Create**: `topic_name`, `partitions` (default 3), `branch` (default `main`). Duplicate topic names are rejected.
- **Destroy**: `topic_name`, `branch` (default `main`).
- **Adjust Partitions**: `topic_name`, `partitions` (new count), `branch` (default `main`). Kafka only allows increasing partitions.

## Customization

- **Repository**: Edit `templates/kafka-topic/template.yaml` to change `repoUrl` or `workflowId`.
- **App config**: Edit `app-config.yaml` for catalog, auth, or other settings.

## Troubleshooting

- **"Failed to load entity kinds" / "Could not fetch catalog entities"**: Ensure `app-config.yaml` has `catalog.rules` allowing `Template` and `backend.cors.origin` set to your frontend URL. Restart with `docker compose down && docker compose up -d`.
- **"Unknown action github:actions:dispatch"**: The official image may not include the GitHub scaffolder module. You can build a custom image from `npx @backstage/create-app` and add `@backstage/plugin-scaffolder-backend-module-github`.
- **"Resource not accessible by personal access token"**: The PAT lacks permissions for workflow dispatch.
  - **Classic PAT** (recommended): Needs `repo` and `workflow` scopes. Create at [github.com/settings/tokens](https://github.com/settings/tokens). If the repo is in an org with SAML SSO, authorize the token via "Configure SSO" on the token.
  - **Fine-grained PAT**: Needs **Actions** → **Read and write** (not just Read) under Repository permissions. "Read and write to codespaces workflows" does not apply to workflow_dispatch.
- **Workflow not triggering**: Ensure `GITHUB_TOKEN` is set before `docker compose up` (same shell or in `.env`).
