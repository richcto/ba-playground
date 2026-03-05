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

export const githubActionsWaitModule = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'github-actions-wait',
  register({ registerInit }) {
    registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
        config: coreServices.rootConfig,
        database: coreServices.database,
      },
      async init({ scaffolder, config, database }) {
        const integrations = ScmIntegrations.fromConfig(config);
        scaffolder.addActions(
          createGithubActionsDispatchAndWaitAction({ integrations }),
          createKafkaTopicCheckDuplicateAction({ database }),
          createKafkaTopicRegisterAction({ database }),
          createKafkaTopicUnregisterAction({ database }),
        );
      },
    });
  },
});
