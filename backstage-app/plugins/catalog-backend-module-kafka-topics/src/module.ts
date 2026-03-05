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
      },
      async init({ catalog, database }) {
        const knex = await database.getClient();
        const provider = new KafkaTopicsEntityProvider(knex);
        catalog.addEntityProvider(provider);
      },
    });
  },
});
