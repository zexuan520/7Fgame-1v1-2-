"""把斜俯视版用到的汉字从 Noto Serif SC（SIL OFL 1.1）里取个子集，存成 assets/fonts/serif-sc.woff2。
伤害数字、连段字、HUD 标题用这个衬线字体。加了新文字以后重新跑一次：
    python3 tools/fonts/fetch_serif.py
用的是 Google Fonts 的 text= 子集接口，只下载需要的字形（几十 KB）。"""
import pathlib, re, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
chars = set("“”‘’—…　▸「」0123456789+-×x!！?？%/:：.·,，、()（）[]【】 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
for f in (ROOT / "scripts" / "arpg").glob("*.gd"):
    for s in re.findall(r'"([^"\n]*)"', f.read_text(encoding="utf-8")):
        chars.update(c for c in s if ord(c) > 0x2E80)
text = "".join(sorted(chars))
ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
url = "https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@700&text=" + urllib.parse.quote(text)
css = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": ua})).read().decode()
font_url = re.search(r"url\((https://[^)]+)\)", css).group(1)
data = urllib.request.urlopen(urllib.request.Request(font_url, headers={"User-Agent": ua})).read()
out = ROOT / "assets" / "fonts" / "serif-sc.woff2"
out.write_bytes(data)
print(len(text), "chars ->", out, len(data), "bytes")
