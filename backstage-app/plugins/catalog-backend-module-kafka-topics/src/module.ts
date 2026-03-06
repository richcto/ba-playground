import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import { catalogProcessingExtensionPoint } from '@backstage/plugin-catalog-node';
import { KafkaTopicsEntityProvider } from './KafkaTopicsEntityProvider';

export const kafkaTopicsCatalogModule = createBackendModule({
  pluginId: 'catalog',
  moduleId: 'kafka-topics',
  register({ registerInit }) {
    registerInit({
      deps: {
        catalog: catalogProcessingExtensionPoint,
        database: coreServices.database,
        logger: coreServices.logger,
      },
      async init({ catalog, database, logger }) {
        const knex = await database.getClient();
        const provider = new KafkaTopicsEntityProvider(knex, logger);
        catalog.addEntityProvider(provider);
        logger.info('Kafka topics entity provider registered');
      },
    });
  },
});
