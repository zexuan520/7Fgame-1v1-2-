#!/usr/bin/env python3
"""数值联调汇总：读 run_matrix.sh 的输出目录，打印每局结果、每层用时/挨打、死因和报错。
用法：python3 tools/balance/report.py 输出目录 [--md]"""
import re, sys, glob, os, collections

def kv(line):
    return dict(re.findall(r'(\w+)=(\S+)', line))

def main():
    out = sys.argv[1]
    md = '--md' in sys.argv
    rows = []
    errs = collections.Counter()
    err_where = {}
    for f in sorted(glob.glob(os.path.join(out, '*.log'))):
        name = os.path.basename(f)[:-4]
        run = None; stall = None; floors = collections.defaultdict(lambda: [0.0, 0.0, 0])
        last_clk = 0.0; rooms = 0
        for line in open(f, errors='replace'):
            line = line.rstrip('\n')
            if line.startswith('RUN '):
                run = kv(line)
            elif line.startswith('STALL'):
                stall = line
            elif line.startswith('TEL clear') or line.startswith('TEL won') or line.startswith('TEL dead'):
                d = kv(line)
                fl = int(d['fl']); fs = floors[fl]
                fs[0] += float(d['secs']); fs[1] += float(d['dmg']); fs[2] += 1
                last_clk = float(d['clk'])
            if ('ERROR' in line or 'SCRIPT ERROR' in line) and 'ConfigFile' not in line:
                key = re.sub(r'\d+', '#', line.strip())[:160]
                errs[key] += 1
                err_where.setdefault(key, name)
        rows.append((name, run, stall, dict(floors), last_clk))
    print('| 局 | 结果 | 到第几层 | 用时(秒) | 悟道 | 挨打 | 受伤总量 | 喝药 | 生命上限 | 伤害倍率 | 受伤倍率 | 死因 |' if md else '')
    if md:
        print('|---|---|---|---|---|---|---|---|---|---|---|---|')
    for name, r, stall, floors, clk in rows:
        if r is None:
            res = 'STALL' if stall else '未结束'
            print(f'| {name} | {res} | {stall or ""} | {clk:.0f} | | | | | | | | |' if md else f'{name}: {res} {stall or ""} last_clk={clk:.0f}')
            continue
        res = '登顶' if r['won'] == 'true' else '身死'
        if md:
            print(f"| {name} | {res} | {r['floor']} | {r['clk']} | {r['lv']} | {r['hits']} | {r['dmg']} | {r['drinks']} | {r['maxhp']} | {r['atk']} | {r['taken']} | {r.get('killer','')} |")
        else:
            print(f"{name}: {res} act={r['act']} wpn={r['weapon']} cyc={r['cycle']} diff={r['diff']} floor={r['floor']} row={r['row']} clk={r['clk']}s lv={r['lv']} hits={r['hits']} dmg={r['dmg']} drinks={r['drinks']} maxhp={r['maxhp']} atk={r['atk']} taken={r['taken']} killer={r.get('killer','')}")
            for fl in sorted(floors):
                s, d, n = floors[fl]
                print(f"    层{fl+1}: {n} 间 {s:.0f} 秒 挨伤 {d:.0f}")
    if errs:
        print('\n报错（次数，首次出现的局）：')
        for k, n in errs.most_common(40):
            print(f'  {n:5d}  [{err_where[k]}] {k}')

main()
