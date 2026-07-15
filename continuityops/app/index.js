import http from 'node:http';

const VERSION = process.env.APP_VERSION ?? '0.1.0-s1';
const SOURCE = process.env.APP_SOURCE ?? 'continuityops-lab';
const IMAGE_DIGEST = process.env.IMAGE_DIGEST ?? 'sha256:unknown';
const PORT = Number.parseInt(process.env.HTTP_PORT ?? '8080', 10);

/**
 * @param {import('node:http').IncomingMessage} req
 * @param {import('node:http').ServerResponse} res
 */
function handleRequest(req, res) {
  const path = req.url?.split('?')[0] ?? '/';

  if (req.method !== 'GET') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'method_not_allowed' }));
    return;
  }

  const timestamp = new Date().toISOString();

  switch (path) {
    case '/healthz':
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', timestamp }));
      return;
    case '/readyz':
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', timestamp }));
      return;
    case '/version':
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          version: VERSION,
          source: SOURCE,
          image_digest: IMAGE_DIGEST,
        }),
      );
      return;
    case '/api/smoke':
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          ok: true,
          check: 'business_smoke',
          message: 'synthetic lab response',
        }),
      );
      return;
    default:
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'not_found' }));
  }
}

const server = http.createServer(handleRequest);

server.listen(PORT, '0.0.0.0', () => {
  console.log(
    JSON.stringify({
      level: 'info',
      message: 'continuityops lab app listening',
      port: PORT,
      version: VERSION,
      timestamp: new Date().toISOString(),
    }),
  );
});
