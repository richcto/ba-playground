/*
 * EntityProvider that reads Kafka topics from the database.
 * Topics are added/removed by scaffolder actions - no repo or git pull needed.
 */

import {
  EntityProvider,
  EntityProviderConnection,
} from '@backstage/plugin-catalog-node';
import { ResourceEntity } from '@backstage/catalog-model';
import { Knex } from 'knex';

const PROVIDER_ID = 'kafka-topics';

export class KafkaTopicsEntityProvider implements EntityProvider {
  constructor(private readonly knex: Knex) {}

  getProviderName(): string {
    return PROVIDER_ID;
  }

  async connect(connection: EntityProviderConnection): Promise<void> {
    await this.ensureTable();
    await this.refresh(connection);
    // Poll every 10s so new topics appear without restart
    setInterval(() => connection.refresh(), 10_000);
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
      // Seed ticket-purchases if migrating from file-based catalog
      try {
        await this.knex('kafka_topics').insert({
          name: 'ticket-purchases',
          title: 'ticket-purchases',
          description: 'Kafka topic for ticket purchases',
        });
      } catch {
        // Ignore if already exists
      }
    }
  }

  async refresh(connection: EntityProviderConnection): Promise<void> {
    const rows = await this.knex('kafka_topics').select('*');
    const entities = rows.map(
      row =>
        ({
          apiVersion: 'backstage.io/v1alpha1',
          kind: 'Resource',
          metadata: {
            name: row.name,
            title: row.title || row.name,
            description: row.description || 'Kafka topic',
            tags: ['kafka'],
          },
          spec: {
            type: 'kafka-topic',
            owner: 'platform',
            system: 'ba-playground',
          },
        }) as ResourceEntity,
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
