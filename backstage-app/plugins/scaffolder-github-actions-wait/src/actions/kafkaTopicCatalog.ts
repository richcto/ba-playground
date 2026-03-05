/*
 * Scaffolder actions for Kafka topic catalog (DB-backed, no repo).
 * - kafka:topic:checkDuplicate: fails if topic exists in catalog (queries kafka_topics table)
 * - kafka:topic:register: adds topic to DB (EntityProvider picks it up)
 * - kafka:topic:unregister: removes topic from DB
 */

import { InputError } from '@backstage/errors';
import {
  createTemplateAction,
  type TemplateAction,
} from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export function createKafkaTopicCheckDuplicateAction(options: {
  database: { getClient: () => Promise<import('knex').Knex> };
}): TemplateAction {
  const { database } = options;
  return createTemplateAction({
    id: 'kafka:topic:checkDuplicate',
    description: 'Fails if the topic already exists in the catalog (DB-backed)',
    schema: {
      input: {
        topic_name: z.string().describe('Topic name to check'),
      },
    },
    async handler(ctx) {
      const { topic_name } = ctx.input;
      const knex = await database.getClient();
      const hasTable = await knex.schema.hasTable('kafka_topics');
      if (hasTable) {
        const existing = await knex('kafka_topics').where({ name: topic_name }).first();
        if (existing) {
          throw new InputError(
            `Topic '${topic_name}' already exists in catalog. Choose a different name or use Adjust Partitions.`,
          );
        }
      }
      ctx.logger.info(`Topic '${topic_name}' is available`);
    },
  });
}

export function createKafkaTopicRegisterAction(options: {
  database: { getClient: () => Promise<import('knex').Knex> };
}): TemplateAction {
  const { database } = options;
  return createTemplateAction({
    id: 'kafka:topic:register',
    description: 'Adds a Kafka topic to the catalog (DB-backed, no repo)',
    schema: {
      input: {
        topic_name: z.string().describe('Topic name'),
        title: z.string().optional().describe('Display title'),
        description: z.string().optional().describe('Description'),
      },
    },
    async handler(ctx) {
      const { topic_name, title, description } = ctx.input;
      const knex = await database.getClient();
      await knex.schema.hasTable('kafka_topics').then(async has => {
        if (!has) {
          await knex.schema.createTable('kafka_topics', table => {
            table.string('name').primary();
            table.string('title');
            table.string('description');
            table.timestamps(true, true);
          });
        }
      });
      const exists = await knex('kafka_topics').where({ name: topic_name }).first();
      if (!exists) {
        await knex('kafka_topics').insert({
          name: topic_name,
          title: title || topic_name,
          description: description || 'Kafka topic',
        });
      }
      ctx.logger.info(`Registered topic '${topic_name}' in catalog`);
    },
  });
}

export function createKafkaTopicUnregisterAction(options: {
  database: { getClient: () => Promise<import('knex').Knex> };
}): TemplateAction {
  const { database } = options;
  return createTemplateAction({
    id: 'kafka:topic:unregister',
    description: 'Removes a Kafka topic from the catalog (DB-backed)',
    schema: {
      input: {
        topic_name: z.string().describe('Topic name to remove'),
      },
    },
    async handler(ctx) {
      const { topic_name } = ctx.input;
      const knex = await database.getClient();
      const deleted = await knex('kafka_topics').where({ name: topic_name }).del();
      if (deleted > 0) {
        ctx.logger.info(`Removed topic '${topic_name}' from catalog`);
      } else {
        ctx.logger.info(`Topic '${topic_name}' was not in catalog`);
      }
    },
  });
}
