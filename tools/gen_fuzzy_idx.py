#!/usr/bin/env python3
"""生成万能Z 紧凑二进制索引 keke_fuzzy_z_<ver>.idx

格式：
  header(20B): 'KKEZ' | ver u8 | 3B pad | n u32 | sig u32 | data_len u32 | 4B pad
  entries: n × 8B (q u32, off u32)，按 q 升序
  data   : 每条 (wlen u8, tier u8, word bytes)
"""
import sys, struct, os

RIME = sys.argv[1]
VER = sys.argv[2]                      # 86 / 98 / nc
OUT = sys.argv[3]

def q_of(code):
    if not (1 <= len(code) <= 4):
        return None
    v = 0
    for ch in code:
        if not ('a' <= ch <= 'z'):
            return None
        v = v * 26 + (ord(ch) - 97)
    return len(code) * 1048576 + v

groups = [(1, f"keke_wubi_{VER}_common"), (2, f"keke_wubi_{VER}_system"), (3, f"keke_wubi_{VER}_rare")]

seen = set()
recs = []
sizes = {}
for tier, name in groups:
    path = os.path.join(RIME, name + ".dict.yaml")
    if not os.path.exists(path):
        raise SystemExit(f"错误：缺少词典文件 {path}（三本必须齐全，否则生成的索引无效）")
    sizes[name] = os.path.getsize(path)
    in_header = True
    with open(path, "rb") as f:
        for raw in f:
            line = raw.decode("utf-8", "ignore").rstrip("\r\n")
            if in_header:
                if line.startswith("..."):
                    in_header = False
                continue
            if not line or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            word = parts[0].strip()
            code = parts[1].strip()
            if len(word) != 1:          # 只收单字（与 utf8.len(word)==1 等价）
                continue
            q = q_of(code)
            if q is None:
                continue
            key = (q, word)
            if key in seen:
                continue
            seen.add(key)
            recs.append((q, word, tier))

recs.sort(key=lambda r: r[0])

data = bytearray()
entries = []
off = 0
for q, word, tier in recs:
    wb = word.encode("utf-8")
    if len(wb) > 255:
        continue
    entries.append((q, off))
    data.append(len(wb)); data.append(tier)
    data.extend(wb)
    off += 2 + len(wb)

sig = 0
for name in sorted(sizes):
    sig = (sig * 131 + sizes[name]) & 0xFFFFFFFF
sig = (sig ^ len(entries)) & 0xFFFFFFFF

with open(OUT, "wb") as f:
    f.write(b"KKEZ")
    f.write(struct.pack("<B3xIII4x", 1, len(entries), sig, len(data)))
    for q, o in entries:
        f.write(struct.pack("<II", q, o))
    f.write(bytes(data))

print(f"{VER}: 条目 {len(entries)}  data {len(data)}  文件 {os.path.getsize(OUT)}  sig {sig}")
