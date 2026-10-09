// 打开官网页面，保存页面加载的所有较大图片，并截一张整页图，供挑选素材。
// 用法：node opus-video/grab-assets.mjs <输出目录> <url> [url...]
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const [outDir, ...urls] = process.argv.slice(2);
mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch();
const seen = new Set();
const index = [];
for (const [i, url] of urls.entries()) {
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
  page.on('response', async res => {
    const ct = res.headers()['content-type'] || '';
    if (!ct.startsWith('image/') || seen.has(res.url())) return;
    try {
      const buf = await res.body();
      if (buf.length < 15000) return;
      seen.add(res.url());
      const ext = ct.split('/')[1].split(';')[0].replace('jpeg', 'jpg');
      const name = `p${i}-${String(index.length).padStart(3, '0')}.${ext}`;
      writeFileSync(path.join(outDir, name), buf);
      index.push({ name, url: res.url(), bytes: buf.length, page: url });
    } catch {}
  });
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
  } catch (e) { console.error('goto', url, e.message.split('\n')[0]); }
  // 滚动一遍触发懒加载
  for (let y = 0; y < 8000; y += 800) { await page.evaluate(y => window.scrollTo(0, y), y).catch(() => {}); await page.waitForTimeout(250); }
  console.error('final url:', url, '->', page.url());
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(outDir, `page-${i}.png`), fullPage: true }).catch(() => {});
  await page.close();
}
writeFileSync(path.join(outDir, 'index.json'), JSON.stringify(index, null, 1));
console.log(index.map(x => `${x.name}\t${x.bytes}\t${x.url}`).join('\n'));
await browser.close();
