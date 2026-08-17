import Fastify from 'fastify';
import { checkDatabase } from './database.js';

function requiredDatabase(env) {
  return String(env.DB_REQUIRED).toLowerCase() === 'true';
}

export function buildApp({ pool = null, env = process.env, logger = true } = {}) {
  const app = Fastify({
    logger,
    trustProxy: true,
    requestIdHeader: 'x-request-id'
  });

  app.get('/', async () => ({
    service: 'cloudops-api',
    version: env.APP_VERSION || 'local',
    environment: env.APP_ENV || 'local'
  }));

  app.get('/health/live', async () => ({ status: 'ok' }));

  app.get('/health/ready', async (_request, reply) => {
    try {
      const database = await checkDatabase(pool);
      if (requiredDatabase(env) && !database.healthy) {
        return reply.code(503).send({ status: 'not-ready', database });
      }
      return { status: 'ready', database };
    } catch (error) {
      app.log.error({ err: error }, 'database readiness check failed');
      return reply.code(503).send({
        status: 'not-ready',
        database: { configured: Boolean(pool), healthy: false }
      });
    }
  });

  app.get('/api/v1/tasks', async (_request, reply) => {
    if (!pool) return reply.code(503).send({ error: 'database is not configured' });
    const result = await pool.query(
      'SELECT id, title, status, created_at FROM tasks ORDER BY created_at DESC LIMIT 100'
    );
    return { items: result.rows };
  });

  app.post('/api/v1/tasks', {
    schema: {
      body: {
        type: 'object',
        additionalProperties: false,
        required: ['title'],
        properties: { title: { type: 'string', minLength: 1, maxLength: 200 } }
      }
    }
  }, async (request, reply) => {
    if (!pool) return reply.code(503).send({ error: 'database is not configured' });
    const result = await pool.query(
      'INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, status, created_at',
      [request.body.title]
    );
    return reply.code(201).send(result.rows[0]);
  });

  app.addHook('onClose', async () => {
    if (pool) await pool.end();
  });

  return app;
}
