// 单帧 / 小样渲染。
// 用法：node opus-video/still.mjs <page.html> <out.png> <秒数> [WxH]
//       node opus-video/still.mjs <page.html> <out.mp4> <开始:时长> [WxH]
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { readFile } from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';

const [page, out, when, size = '1080x1920'] = process.argv.slice(2);
const [W, H] = size.split('x').map(Number);

// 本地静态服务器：ES 模块（如 three.js）不能从 file:// 加载
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.woff': 'font/woff', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json' };
const server = http.createServer(async (req, res) => {
  try {
    const file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!file.startsWith(root)) throw new Error('outside root');
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({ args: ['--enable-gpu', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'] });
const p = await browser.newPage({ viewport: { width: W, height: H } });
p.on('pageerror', e => console.error('pageerror:', e.message));
p.on('console', m => { if (m.type() === 'error') console.error('console:', m.text()); });
await p.goto(base + path.relative(root, path.resolve(page)).split(path.sep).join('/'));
await p.waitForFunction('typeof window.render === "function" && (window.ready === undefined || window.ready === true)', null, { timeout: 60000 });
await p.evaluate(() => document.fonts.ready);

if (!out.endsWith('.mp4')) {
  // 渲两遍：第一遍触发字形子集加载
  await p.evaluate(t => window.render(t), +when);
  await p.evaluate(() => document.fonts.ready);
  await p.evaluate(t => window.render(t), +when);
  await p.screenshot({ path: out });
} else {
  const [s, d] = when.split(':').map(Number);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', '30', '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  for (let i = 0; i < d * 30; i++) {
    await p.evaluate(t => window.render(t), s + i / 30);
    ff.stdin.write(await p.screenshot({ type: 'jpeg', quality: 92 }));
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
}
await browser.close();
server.close();
