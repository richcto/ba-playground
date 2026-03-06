/*
 * EntityProvider that reads Kafka topics from the database.
 * Topics are added/removed by scaffolder actions - no repo or git pull needed.
 */

import {
  EntityProvider,
  EntityProviderConnection,
} from '@backstage/plugin-catalog-node';
import { ResourceEntity } from '@backstage/catalog-model';
import { LoggerService } from '@backstage/backend-plugin-api';
import { Knex } from 'knex';

const PROVIDER_ID = 'kafka-topics';

export class KafkaTopicsEntityProvider implements EntityProvider {
  constructor(
    private readonly knex: Knex,
    private readonly logger: LoggerService,
  ) {}

  getProviderName(): string {
    return PROVIDER_ID;
  }

  async connect(connection: EntityProviderConnection): Promise<void> {
    this.logger.info('Kafka topics entity provider connecting');
    await this.ensureTable();
    await this.refresh(connection);
    // Poll every 10s so new topics appear without restart (full refresh, not incremental)
    setInterval(() => this.refresh(connection), 10_000);
    this.logger.info('Kafka topics entity provider connected and polling');
  }

  private async ensureTable(): Promise<void> {
    const hasTable = await this.knex.schema.hasTable('kafka_topics');
    if (!hasTable) {
      await this.knex.schema.createTable('kafka_topics', table => {
        table.string('name').primary();
        table.string('title');
        table.string('description');
        table.timestamps(true, true);
      });
    }
  }

  async refresh(connection: EntityProviderConnection): Promise<void> {
    const rows = await this.knex('kafka_topics').select('*');
    const entities = rows.map(
      row => {
        const locationKey = `${PROVIDER_ID}:${row.name}`;
        return {
          apiVersion: 'backstage.io/v1alpha1',
          kind: 'Resource',
          metadata: {
            name: row.name,
            namespace: 'default',
            title: row.title || row.name,
            description: row.description || 'Kafka topic',
            tags: ['kafka'],
            annotations: {
              'backstage.io/managed-by-location': locationKey,
              'backstage.io/managed-by-origin-location': locationKey,
            },
          },
          spec: {
            type: 'kafka-topic',
            owner: 'platform',
            system: 'examples',
          },
        } as ResourceEntity;
      },
    );

    this.logger.info(
      `Kafka topics entity provider refreshing: ${entities.length} topics from DB [${entities.map(e => e.metadata.name).join(', ')}]`,
    );

    await connection.applyMutation({
      type: 'full',
      entities: entities.map(entity => ({
        entity,
        locationKey: `${PROVIDER_ID}:${entity.metadata.name}`,
      })),
    });
  }
}
