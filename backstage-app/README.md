# Custom Backstage App (with workflow status polling)

This Backstage app includes a custom scaffolder action `github:actions:dispatchAndWait` that dispatches a GitHub Actions workflow and **polls until completion**, streaming status into the scaffolder task logs.

## Build

Requires [Yarn](https://yarnpkg.com/) (the project uses Yarn workspaces):

```bash
yarn install
yarn build:backend
```

## Docker

Build the custom image from the `backstage` directory:

```bash
cd ../backstage
docker compose -f docker-compose.custom.yml build
docker compose -f docker-compose.custom.yml up -d
```

The build uses the pre-built backend from this directory. Run `yarn build:backend` before building the Docker image.
