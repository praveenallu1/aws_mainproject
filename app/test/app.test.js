import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';

test('liveness endpoint is independent of dependencies', async (t) => {
  const app = buildApp({ logger: false, env: {} });
  t.after(() => app.close());

  const response = await app.inject({ method: 'GET', url: '/health/live' });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: 'ok' });
});

test('readiness passes without a database when it is optional', async (t) => {
  const app = buildApp({ logger: false, env: { DB_REQUIRED: 'false' } });
  t.after(() => app.close());

  const response = await app.inject({ method: 'GET', url: '/health/ready' });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().database.configured, false);
});

test('readiness fails when the required database is unavailable', async (t) => {
  const app = buildApp({ logger: false, env: { DB_REQUIRED: 'true' } });
  t.after(() => app.close());

  const response = await app.inject({ method: 'GET', url: '/health/ready' });
  assert.equal(response.statusCode, 503);
});

test('task endpoint rejects invalid input before reaching the database', async (t) => {
  const app = buildApp({ logger: false, env: {} });
  t.after(() => app.close());

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/tasks',
    payload: { title: '' }
  });
  assert.equal(response.statusCode, 400);
});
