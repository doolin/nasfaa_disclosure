// lambda.js — minimal AWS Lambda handler for blurbpress.com/nasfaa-disclose-or-not
//
// Designed for API Gateway HTTP API or a direct Lambda Function URL.
// Bundles the static files alongside this handler and serves them from
// the in-process filesystem. Node 20 runtime, no Express, no build step.
//
// Routes (anything else returns 404):
//   GET  /nasfaa-disclose-or-not                   -> index.html
//   GET  /nasfaa-disclose-or-not/                  -> index.html
//   GET  /nasfaa-disclose-or-not/<file>            -> ./<file>
//   GET  /nasfaa-disclose-or-not/test.html         -> test.html
//
// Deployment notes:
//   1. Zip this whole directory (`web/walkthrough/`) and upload as the Lambda
//      package. Set handler to `lambda.handler`.
//   2. Front with a Function URL or API Gateway. Map the base path
//      `/nasfaa-disclose-or-not` to this Lambda.
//   3. Cache static assets at the edge (CloudFront) for free.

import { readFile } from 'node:fs/promises';
import { dirname, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASE_PATH = '/nasfaa-disclose-or-not';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
};

const ALLOWED = new Set([
  'index.html',
  'test.html',
  'app.js',
  'tests.js',
  'engine.js',
  'dag.js',
  'box-draw.js',
  'styles.css',
  'rules.json',
  'questions.json',
  'scenarios.json',
]);

function extOf(p) {
  const dot = p.lastIndexOf('.');
  return dot < 0 ? '' : p.slice(dot).toLowerCase();
}

function rawPath(event) {
  // API Gateway HTTP API (v2) or Function URL: event.rawPath
  // API Gateway REST (v1): event.path
  return event.rawPath || event.path || '/';
}

function methodOf(event) {
  return (
    event.requestContext?.http?.method ||
    event.httpMethod ||
    'GET'
  ).toUpperCase();
}

function notFound() {
  return {
    statusCode: 404,
    headers: { 'content-type': 'text/plain; charset=utf-8' },
    body: 'Not Found',
  };
}

function methodNotAllowed() {
  return {
    statusCode: 405,
    headers: { 'content-type': 'text/plain; charset=utf-8', allow: 'GET, HEAD' },
    body: 'Method Not Allowed',
  };
}

export async function handler(event) {
  if (!['GET', 'HEAD'].includes(methodOf(event))) return methodNotAllowed();

  let path = rawPath(event);
  if (!path.startsWith(BASE_PATH)) return notFound();
  let rest = path.slice(BASE_PATH.length);
  if (rest === '' || rest === '/') rest = '/index.html';

  // Strip leading slash, normalize, prevent path traversal.
  const relPath = normalize(rest.replace(/^\/+/, ''));
  if (relPath.startsWith('..')) return notFound();
  const fileName = relPath.split(/[\/\\]/).pop();
  if (!ALLOWED.has(fileName)) return notFound();

  const fsPath = resolve(HERE, fileName);
  // Defence in depth: ensure resolved path is exactly a file in HERE.
  if (dirname(fsPath) !== HERE) return notFound();

  let body;
  try {
    body = await readFile(fsPath);
  } catch {
    return notFound();
  }

  const ext = extOf(fileName);
  const type = MIME[ext] || 'application/octet-stream';
  const isBinary = !type.includes('charset');
  return {
    statusCode: 200,
    headers: {
      'content-type': type,
      'cache-control':
        ext === '.html' ? 'no-cache' : 'public, max-age=300, must-revalidate',
    },
    isBase64Encoded: isBinary,
    body: isBinary ? body.toString('base64') : body.toString('utf8'),
  };
}
