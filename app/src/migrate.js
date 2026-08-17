import { readFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createDatabase } from './database.js';

const pool = createDatabase();
if (!pool) throw new Error('DB_HOST must be set before running migrations');

const migrationDirectory = join(dirname(fileURLToPath(import.meta.url)), '..', 'db', 'migrations');
const client = await pool.connect();

try {
  await client.query('SELECT pg_advisory_lock($1)', [8072026]);
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  const files = (await readdir(migrationDirectory)).filter((name) => name.endsWith('.sql')).sort();
  for (const name of files) {
    const applied = await client.query('SELECT 1 FROM schema_migrations WHERE name = $1', [name]);
    if (applied.rowCount > 0) continue;

    const sql = await readFile(join(migrationDirectory, name), 'utf8');
    await client.query('BEGIN');
    try {
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [name]);
      await client.query('COMMIT');
      console.log(JSON.stringify({ level: 'info', message: 'migration applied', migration: name }));
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
  }
} finally {
  await client.query('SELECT pg_advisory_unlock($1)', [8072026]);
  client.release();
  await pool.end();
}

