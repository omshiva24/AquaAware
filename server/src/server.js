import { readFileSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import { pathToFileURL } from 'node:url';

import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { openDatabase } from './db.js';

export function createAquaServer(config, { db = openDatabase(config.dbPath), log } = {}) {
  const app = createApp(config, { db, log });
  const server = config.tlsCert && config.tlsKey
    ? https.createServer(
        { cert: readFileSync(config.tlsCert), key: readFileSync(config.tlsKey), minVersion: 'TLSv1.2' },
        app.handle,
      )
    : http.createServer(app.handle);

  // Slow-loris protection; SSE responses are long-lived but their requests are small.
  server.headersTimeout = 10_000;
  server.requestTimeout = 15_000;
  server.keepAliveTimeout = 5_000;
  server.maxHeadersCount = 50;

  const close = () =>
    new Promise((resolve) => {
      app.close();
      server.close(() => {
        try {
          db.close();
        } catch {
          // already closed
        }
        resolve();
      });
      server.closeAllConnections?.();
    });

  return { server, app, db, close };
}

async function main() {
  const config = loadConfig();
  const { server, close } = createAquaServer(config);
  server.listen(config.port, config.host, () => {
    const scheme = config.tlsCert ? 'https' : 'http';
    console.log(`AquaAware API listening on ${scheme}://${config.host}:${config.port}`);
  });
  const stop = async (signal) => {
    console.log(`${signal} received, shutting down…`);
    await close();
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
