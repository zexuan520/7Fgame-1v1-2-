// 逐帧渲染 index.html 并用 ffmpeg 编码成 MP4。
// 用法：node video/render.mjs [输出文件] [--preview 秒数,秒数,...]
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const FPS = 30;
const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const previewIdx = args.indexOf('--preview');
const preview = previewIdx >= 0 ? args[previewIdx + 1].split(',').map(Number) : null;
const out = (previewIdx === 0 ? null : args[0]) || path.join(here, 'out', 'qifan-chronicle.mp4');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
await page.goto(pathToFileURL(path.join(here, 'index.html')).href);
await page.evaluate(() => document.fonts.ready);
// 预渲染每个场景一次，确保所有字形子集都已加载
const total = await page.evaluate(() => window.TOTAL);
for (let t = 0; t < total; t += 0.5) await page.evaluate(t => window.render(t), t);
await page.evaluate(() => document.fonts.ready);

if (preview) {
  for (const t of preview) {
    await page.evaluate(t => window.render(t), t);
    await page.screenshot({ path: path.join(here, 'out', `preview-${t}.png`) });
  }
  await browser.close();
  process.exit(0);
}

const ff = spawn('ffmpeg', ['-y', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '18', '-movflags', '+faststart', out],
  { stdio: ['pipe', 'inherit', 'inherit'] });

const frames = Math.round(total * FPS);
for (let i = 0; i < frames; i++) {
  await page.evaluate(t => window.render(t), i / FPS);
  const buf = await page.screenshot({ type: 'jpeg', quality: 92 });
  if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  if (i % 150 === 0) console.log(`frame ${i}/${frames}`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close();
console.log('done:', out);
