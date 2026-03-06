import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node';
import { createGithubActionsDispatchAndWaitAction } from './actions/githubActionsDispatchAndWait';
import {
  createKafkaTopicCheckDuplicateAction,
  createKafkaTopicRegisterAction,
  createKafkaTopicUnregisterAction,
} from './actions/kafkaTopicCatalog';
import { ScmIntegrations } from '@backstage/integration';
import knex from 'knex';

/** Catalog DB client for kafka_topics - entity provider reads from same DB */
function createCatalogDbForKafka(config: { getConfig: (key: string) => { getConfig: (k: string) => { get: (k?: string) => unknown }; get: (k?: string) => unknown } }) {
  const dbConfig = config.getConfig('backend').getConfig('database');
  const conn = dbConfig.get('connection') as Record<string, unknown>;
  const client = (dbConfig.get('client') as string) || 'pg';
  const knexClient = knex({
    client,
    connection: { ...conn, database: 'backstage_plugin_catalog' },
  });
  return {
    getClient: () => Promise.resolve(knexClient),
  };
}

export const githubActionsWaitModule = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'github-actions-wait',
  register({ registerInit }) {
    registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
        config: coreServices.rootConfig,
      },
      async init({ scaffolder, config }) {
        const integrations = ScmIntegrations.fromConfig(config);
        const catalogDb = createCatalogDbForKafka(config);
        scaffolder.addActions(
          createGithubActionsDispatchAndWaitAction({ integrations }),
          createKafkaTopicCheckDuplicateAction({ database: catalogDb }),
          createKafkaTopicRegisterAction({ database: catalogDb }),
          createKafkaTopicUnregisterAction({ database: catalogDb }),
        );
      },
    });
  },
});
