// 整片渲染：逐帧调用 render(t) 截图 → 合成配乐 → ffmpeg 混合并做响度标准化。
// 用法：node opus-video/render.mjs <项目目录>    例：node opus-video/render.mjs opus-video/qifan-chronicle
// 项目目录需有 index.html（暴露 window.render / TOTAL / CUES）和 score.py。
import { chromium } from 'playwright';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';

const FPS = 30;
const proj = path.resolve(process.argv[2]);
const outDir = path.join(proj, 'out'), audioDir = path.join(proj, 'audio');
await mkdir(outDir, { recursive: true }); await mkdir(audioDir, { recursive: true });

// 本地静态服务器（ES 模块和字体不能走 file://）
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.woff': 'font/woff', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json' };
const server = http.createServer(async (req, res) => {
  try {
    const file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!file.startsWith(root)) throw new Error('outside root');
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));

const browser = await chromium.launch({ args: ['--enable-gpu', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
page.on('pageerror', e => console.error('pageerror:', e.message));
await page.goto(`http://127.0.0.1:${server.address().port}/${path.relative(root, path.join(proj, 'index.html'))}`);
await page.waitForFunction('window.ready === true', null, { timeout: 90000 });
const total = await page.evaluate(() => window.TOTAL);
for (let t = 0; t < total; t += .5) await page.evaluate(t => window.render(t), t);   // 预热字形
await page.evaluate(() => document.fonts.ready);

// 配乐
const cues = await page.evaluate(() => window.CUES);
const cuesPath = path.join(audioDir, 'cues.json'), wav = path.join(audioDir, 'score.wav');
await writeFile(cuesPath, JSON.stringify({ total, cues }));
execFileSync('python3', [path.join(proj, 'score.py'), cuesPath, wav], { stdio: 'inherit' });

const out = path.join(outDir, 'final.mp4');
const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-', '-i', wav,
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '20', '-maxrate', '8M', '-bufsize', '16M',
  '-af', 'loudnorm=I=-14:TP=-1.5:LRA=11', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
  '-shortest', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });

const t0 = Date.now();
const frames = Math.round(total * FPS);
for (let i = 0; i < frames; i++) {
  await page.evaluate(t => window.render(t), i / FPS);
  const buf = await page.screenshot({ type: 'jpeg', quality: 93 });
  if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  if (i % 300 === 0) console.log(`frame ${i}/${frames}  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close(); server.close();
console.log(`done: ${out}  (${((Date.now() - t0) / 60000).toFixed(1)} min)`);
