import { buildApp } from './app.js';
import { createDatabase } from './database.js';

const pool = createDatabase();
const app = buildApp({ pool });
const port = Number(process.env.PORT || 3000);

async function shutdown(signal) {
  app.log.info({ signal }, 'graceful shutdown started');
  try {
    await app.close();
    process.exit(0);
  } catch (error) {
    app.log.error({ err: error }, 'graceful shutdown failed');
    process.exit(1);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

try {
  await app.listen({ port, host: '0.0.0.0' });
} catch (error) {
  app.log.error({ err: error }, 'service failed to start');
  process.exit(1);
}

