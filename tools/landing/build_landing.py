"""手机端发布用的竖屏动画封面：tools/landing/landing.src.html → 根目录 landing.html。
把页面里用到的汉字从 Noto Serif SC（SIL OFL 1.1）取子集，base64 内嵌（页面不能有外部请求）。
改了 landing.src.html 以后重新跑：python3 tools/landing/build_landing.py
build-web.cmd 会把根目录的 landing.html 原样复制进 dist/。"""
import base64, pathlib, re, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
src = (ROOT / "tools" / "landing" / "landing.src.html").read_text(encoding="utf-8")
body = re.sub(r"<!--.*?-->", "", src, flags=re.S)
chars = set("0123456789/·+×x! ")
chars.update(c for c in body if ord(c) > 0x2E80)
text = "".join(sorted(chars))
ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
url = "https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@700&text=" + urllib.parse.quote(text)
css = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": ua})).read().decode()
font_url = re.search(r"url\((https://[^)]+)\)", css).group(1)
data = urllib.request.urlopen(urllib.request.Request(font_url, headers={"User-Agent": ua})).read()
out = ROOT / "landing.html"
out.write_text(src.replace("__FONT__", base64.b64encode(data).decode()), encoding="utf-8", newline="\n")
print(len(text), "chars,", len(data), "bytes font ->", out)
