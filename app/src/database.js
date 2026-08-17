import pg from 'pg';

const { Pool } = pg;

function isTrue(value) {
  return String(value).toLowerCase() === 'true';
}

export function databaseConfig(env = process.env) {
  if (!env.DB_HOST) return null;

  return {
    host: env.DB_HOST,
    port: Number(env.DB_PORT || 5432),
    database: env.DB_NAME || 'cloudops',
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    max: Number(env.DB_POOL_MAX || 10),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 3_000,
    ssl: isTrue(env.DB_SSL) ? { rejectUnauthorized: true } : false
  };
}

export function createDatabase(env = process.env) {
  const config = databaseConfig(env);
  return config ? new Pool(config) : null;
}

export async function checkDatabase(pool) {
  if (!pool) return { configured: false, healthy: false };
  const startedAt = performance.now();
  await pool.query('SELECT 1');
  return {
    configured: true,
    healthy: true,
    latencyMs: Math.round(performance.now() - startedAt)
  };
}

