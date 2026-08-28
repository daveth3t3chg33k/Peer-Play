const http = require('http');
const fs = require('fs');
const path = require('path');

const BUNDLE_PATH = '/home/kam1rah/Peer-Play/mobile/index.android.bundle.js';
const PORT = 8081;

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  
  console.log(`[${new Date().toISOString()}] ${req.method} ${url.pathname}`);
  
  // Metro status check — must return exact plain text string
  if (url.pathname === '/status') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('packager-status:running');
    return;
  }
  
  // JS bundle
  if (url.pathname === '/index.android.bundle' || url.pathname === '/index.android.bundle.js') {
    try {
      const bundle = fs.readFileSync(BUNDLE_PATH);
      res.writeHead(200, {
        'Content-Type': 'application/javascript; charset=UTF-8',
        'Content-Length': bundle.length,
        'Cache-Control': 'no-cache',
      });
      res.end(bundle);
    } catch (e) {
      console.error('Bundle read error:', e.message);
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Bundle not found');
    }
    return;
  }
  
  // Symbolicate endpoint (stub)
  if (url.pathname === '/symbolicate') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end('{}');
    return;
  }
  
  // Reload endpoint (stub)
  if (url.pathname === '/reload') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  
  // Inspector endpoints (stub)
  if (url.pathname.startsWith('/inspector')) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
    return;
  }
  
  // Default: serve the bundle for any path
  try {
    const bundle = fs.readFileSync(BUNDLE_PATH);
    res.writeHead(200, {
      'Content-Type': 'application/javascript; charset=UTF-8',
      'Content-Length': bundle.length,
      'Cache-Control': 'no-cache',
    });
    res.end(bundle);
  } catch (e) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Metro-compatible server listening on http://0.0.0.0:${PORT}`);
  console.log(`Bundle: ${BUNDLE_PATH} (${fs.existsSync(BUNDLE_PATH) ? 'EXISTS - ' + fs.statSync(BUNDLE_PATH).size + ' bytes' : 'MISSING'})`);
});
