// 逐帧渲染 index.html，生成配乐，并用 ffmpeg 合成 MP4。
// 用法：
//   node video/render.mjs                    完整渲染（含音轨）
//   node video/render.mjs --preview 3,9,16   只导出指定秒数的预览帧
// 素材：把截图 / Logo 放到 video/assets/（文件名见 assets/README.md），缺失时自动使用程序生成的画面。
import { chromium } from 'playwright';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const FPS = 30;
const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(here, 'out');
mkdirSync(outDir, { recursive: true });
const args = process.argv.slice(2);
const previewIdx = args.indexOf('--preview');
const preview = previewIdx >= 0 ? args[previewIdx + 1].split(',').map(Number) : null;
const out = path.join(outDir, 'qifan-chronicle.mp4');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
await page.goto(pathToFileURL(path.join(here, 'index.html')).href);
await page.evaluate(() => window.assetsReady);
// 先把每个场景都渲染一遍，让所有字形子集加载完
const total = await page.evaluate(() => window.TOTAL);
for (let t = 0; t < total; t += 0.5) await page.evaluate(t => window.render(t), t);
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(500);

if (preview) {
  for (const t of preview) {
    await page.evaluate(t => window.render(t), t);
    await page.screenshot({ path: path.join(outDir, `preview-${t}.png`) });
  }
  await browser.close();
  process.exit(0);
}

// 配乐
const cues = await page.evaluate(() => window.CUES);
const cuesPath = path.join(outDir, 'cues.json');
writeFileSync(cuesPath, JSON.stringify({ total, cues }));
const wav = path.join(outDir, 'score.wav');
execFileSync('python3', [path.join(here, 'score.py'), cuesPath, wav], { stdio: 'inherit' });

const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
  '-i', wav,
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '17', '-tune', 'film',
  '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', out],
  { stdio: ['pipe', 'inherit', 'inherit'] });

const frames = Math.round(total * FPS);
for (let i = 0; i < frames; i++) {
  await page.evaluate(t => window.render(t), i / FPS);
  const buf = await page.screenshot({ type: 'jpeg', quality: 93 });
  if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  if (i % 300 === 0) console.log(`frame ${i}/${frames}`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close();
console.log('done:', out);
