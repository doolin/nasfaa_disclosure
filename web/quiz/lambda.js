// lambda.js — Minimal AWS Lambda handler for the NASFAA disclosure quiz.
//
// Runtime: Node.js 20.x (uses only the Node standard library).
// Designed for: API Gateway HTTP API v2 events OR Lambda Function URLs.
//
// Serves the static files in this directory under the base path
// /nasfaa-disclosure-quiz/  (e.g. clubstraylight.com/nasfaa-disclosure-quiz/).
// Any request whose path resolves to a file in this directory is returned;
// any request to the bare base path returns index.html.
//
// Deploy:
//   zip -r quiz-lambda.zip .            (run from web/quiz/)
//   aws lambda create-function \
//     --function-name nasfaa-disclosure-quiz \
//     --runtime nodejs20.x \
//     --handler lambda.handler \
//     --zip-file fileb://quiz-lambda.zip \
//     --role <execution-role-arn>
//
// Then attach a Lambda Function URL or wire to API Gateway HTTP API.

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const BASE_PATH = '/nasfaa-disclosure-quiz';
const ASSET_DIR = __dirname;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg':  'image/svg+xml',
  '.png':  'image/png',
  '.ico':  'image/x-icon',
  '.txt':  'text/plain; charset=utf-8',
  '.md':   'text/markdown; charset=utf-8',
};

const ALLOWED_FILES = new Set([
  'index.html',
  'app.js',
  'engine.js',
  'quiz.js',
  'box-draw.js',
  'styles.css',
  'rules.json',
  'scenarios.json',
]);

function extractPath(event) {
  // API Gateway HTTP API v2 + Lambda Function URL both use rawPath.
  if (event.rawPath) return event.rawPath;
  if (event.path) return event.path;
  if (event.requestContext && event.requestContext.http && event.requestContext.http.path) {
    return event.requestContext.http.path;
  }
  return '/';
}

function extractMethod(event) {
  if (event.requestContext && event.requestContext.http && event.requestContext.http.method) {
    return event.requestContext.http.method;
  }
  return event.httpMethod || 'GET';
}

function notFound() {
  return {
    statusCode: 404,
    headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' },
    body: 'Not Found',
  };
}

function methodNotAllowed() {
  return {
    statusCode: 405,
    headers: { 'content-type': 'text/plain; charset=utf-8', 'allow': 'GET, HEAD' },
    body: 'Method Not Allowed',
  };
}

function fileResponse(filename) {
  if (!ALLOWED_FILES.has(filename)) return notFound();
  const full = path.join(ASSET_DIR, filename);
  if (!full.startsWith(ASSET_DIR)) return notFound();  // path-traversal guard
  let buf;
  try { buf = fs.readFileSync(full); }
  catch (_e) { return notFound(); }
  const ext = path.extname(filename).toLowerCase();
  const ct = MIME[ext] || 'application/octet-stream';
  const isText = ct.includes('text/') || ct.includes('json') || ct.includes('javascript') || ct.includes('svg');
  return {
    statusCode: 200,
    headers: {
      'content-type': ct,
      'cache-control': filename.endsWith('.json') ? 'public, max-age=300' : 'public, max-age=3600',
    },
    body: isText ? buf.toString('utf8') : buf.toString('base64'),
    isBase64Encoded: !isText,
  };
}

exports.handler = async (event) => {
  const method = extractMethod(event);
  if (method !== 'GET' && method !== 'HEAD') return methodNotAllowed();

  let p = extractPath(event) || '/';
  // Strip base path if present.
  if (p === BASE_PATH || p === BASE_PATH + '/') {
    return fileResponse('index.html');
  }
  if (p.startsWith(BASE_PATH + '/')) {
    p = p.slice(BASE_PATH.length);
  }
  if (p === '/' || p === '') {
    return fileResponse('index.html');
  }
  // p now looks like "/app.js" — strip leading slash and route.
  const filename = p.replace(/^\/+/, '');
  if (filename.includes('/') || filename.includes('..')) return notFound();
  if (filename === '') return fileResponse('index.html');
  return fileResponse(filename);
};
