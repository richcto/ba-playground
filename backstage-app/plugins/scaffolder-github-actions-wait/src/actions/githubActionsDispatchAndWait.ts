/*
 * Custom action that dispatches a GitHub Actions workflow and polls until completion.
 * Logs status to the scaffolder task (visible to user) and outputs final result.
 */

import { InputError } from '@backstage/errors';
import {
  DefaultGithubCredentialsProvider,
  ScmIntegrations,
} from '@backstage/integration';
import {
  createTemplateAction,
  parseRepoUrl,
} from '@backstage/plugin-scaffolder-node';
import { Octokit } from 'octokit';
import { z } from 'zod';

const POLL_INTERVAL_MS = 10_000;
const MAX_WAIT_MS = 15 * 60 * 1000; // 15 minutes
const INITIAL_DELAY_MS = 5_000; // Wait for run to appear

async function getOctokit(
  integrations: ScmIntegrations,
  repoUrl: string,
  token?: string,
) {
  const { host, owner, repo } = parseRepoUrl(repoUrl, integrations);
  if (!owner || !repo) {
    throw new InputError('Invalid repoUrl: missing owner or repo');
  }
  const integrationConfig = integrations.github.byHost(host || 'github.com')?.config;
  if (!integrationConfig) {
    throw new InputError(`No GitHub integration for host ${host}`);
  }
  let auth = token;
  if (!auth) {
    const creds = await DefaultGithubCredentialsProvider.fromIntegrations(
      integrations,
    ).getCredentials({
      url: `https://${host}/${owner}/${repo}`,
    });
    auth = creds?.token;
  }
  if (!auth) {
    throw new InputError('No GitHub token available. Set GITHUB_TOKEN in scaffolder secrets.');
  }
  return {
    octokit: new Octokit({ auth, baseUrl: integrationConfig.apiBaseUrl }),
    owner,
    repo,
  };
}

export function createGithubActionsDispatchAndWaitAction(options: {
  integrations: ScmIntegrations;
}) {
  const { integrations } = options;

  return createTemplateAction({
    id: 'github:actions:dispatchAndWait',
    description: 'Dispatches a GitHub Actions workflow and polls until it completes. Status is logged and visible in the task.',
    schema: {
      input: {
        repoUrl: z.string().describe('Accepts github.com?repo=reponame&owner=owner'),
        workflowId: z.string().describe('The workflow filename (e.g. deploy-kafka.yml)'),
        branchOrTagName: z.string().describe('Branch or tag to run the workflow on'),
        workflowInputs: z.record(z.string()).optional().describe('Inputs to pass to the workflow'),
        token: z.string().optional().describe('GitHub token (or use GITHUB_TOKEN from secrets)'),
      },
      output: {
        runId: z.number(),
        runUrl: z.string(),
        status: z.string(),
        conclusion: z.string(),
      },
    },
    async handler(ctx) {
      const {
        repoUrl,
        workflowId,
        branchOrTagName,
        workflowInputs,
        token: providedToken,
      } = ctx.input;

      ctx.logger.info(
        `Dispatching workflow ${workflowId} for ${repoUrl} on ${branchOrTagName}`,
      );

      const { octokit, owner, repo } = await getOctokit(
        integrations,
        repoUrl,
        providedToken,
      );

      const dispatchResponse = await octokit.rest.actions.createWorkflowDispatch({
        owner,
        repo,
        workflow_id: workflowId,
        ref: branchOrTagName,
        inputs: workflowInputs as Record<string, string> | undefined,
        return_run_details: true,
      });

      let run: { id: number; status: string; conclusion: string | null; html_url?: string };
      const runIdFromResponse = (dispatchResponse.data as { workflow_run_id?: number })
        ?.workflow_run_id;

      if (runIdFromResponse) {
        ctx.logger.info('Workflow dispatched. Polling run from API response...');
        const { data: runData } = await octokit.rest.actions.getWorkflowRun({
          owner,
          repo,
          run_id: runIdFromResponse,
        });
        run = runData;
      } else {
        ctx.logger.info('Workflow dispatched. Waiting for run to appear...');
        await new Promise(r => setTimeout(r, INITIAL_DELAY_MS));

        const { data: runs } = await octokit.rest.actions.listWorkflowRunsForRepo({
          owner,
          repo,
          workflow_id: workflowId,
          event: 'workflow_dispatch',
          per_page: 5,
        });

        const found = runs.workflow_runs.find(
          r =>
            r.status === 'queued' ||
            r.status === 'in_progress' ||
            (r.status === 'completed' && Date.now() - new Date(r.updated_at).getTime() < 60_000),
        );

        if (!found) {
          throw new InputError(
            'Could not find the dispatched workflow run. It may have completed very quickly or failed to start.',
          );
        }
        run = found;
      }

      const runUrl = run.html_url || `https://github.com/${owner}/${repo}/actions/runs/${run.id}`;
      ctx.logger.info(`Found run ${run.id}. Polling for completion: ${runUrl}`);

      const startTime = Date.now();
      let lastStatus = run.status;
      let lastConclusion = run.conclusion;

      while (Date.now() - startTime < MAX_WAIT_MS) {
        const { data: runData } = await octokit.rest.actions.getWorkflowRun({
          owner,
          repo,
          run_id: run.id,
        });

        lastStatus = runData.status;
        lastConclusion = runData.conclusion;

        ctx.logger.info(
          `Workflow status: ${lastStatus}${lastConclusion ? ` (${lastConclusion})` : ''}`,
        );

        if (lastStatus === 'completed') {
          ctx.output('runId', run.id);
          ctx.output('runUrl', runUrl);
          ctx.output('status', lastStatus);
          ctx.output('conclusion', lastConclusion || 'unknown');

          if (lastConclusion === 'success') {
            ctx.logger.info('Workflow completed successfully.');
          } else {
            ctx.logger.warn(`Workflow completed with conclusion: ${lastConclusion}`);
          }
          return;
        }

        await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      }

      ctx.logger.warn(`Workflow did not complete within ${MAX_WAIT_MS / 60_000} minutes.`);
      ctx.output('runId', run.id);
      ctx.output('runUrl', runUrl);
      ctx.output('status', lastStatus);
      ctx.output('conclusion', lastConclusion || 'timeout');
    },
  });
}
