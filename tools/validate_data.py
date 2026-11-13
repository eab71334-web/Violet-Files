#!/usr/bin/env python3
"""يتحقق من ملفات القضايا بدون محرك Godot (يعمل على الجوال عبر Termux أو على الكمبيوتر).
Validates case JSON files without Godot:  python3 tools/validate_data.py
"""
import json, re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVEAL = {"light", "uv", "print", "detail"}
errors = []

def err(msg): errors.append(msg)

SHOP = json.load(open(f"{ROOT}/data/shop.json", encoding="utf8"))
index = json.load(open(f"{ROOT}/data/cases/index.json", encoding="utf8"))
if len(index) != 10: err("index must list 10 cases")

for e in index:
    if not e["playable"]:
        continue
    cid = e["id"]
    c = json.load(open(f"{ROOT}/data/cases/{cid}.json", encoding="utf8"))
    ids = {o["id"] for o in c["question"]["options"]}
    if sum(1 for o in c["question"]["options"] if o["correct"]) != 1:
        err(f"{cid}: need exactly one correct option")
    items = set()
    for sc in c["scenes"]:
        for it in sc.get("items", []):
            if it["id"] in items: err(f"{cid}: duplicate item {it['id']}")
            items.add(it["id"])
            if it["needs"] != "none" and it["needs"] not in REVEAL: err(f"{cid}: bad needs {it['needs']}")
            if it["kind"] not in ("real", "misleading"): err(f"{cid}: bad kind on {it['id']}")
            for s in it.get("supports", []):
                if s not in ids: err(f"{cid}: {it['id']} supports unknown answer {s}")
            if not (0 <= it["x"] <= 1 and 0 <= it["y"] <= 1): err(f"{cid}: {it['id']} x/y out of range")
        for req in sc.get("requires", []):
            if req not in {s["id"] for s in c["scenes"]}: err(f"{cid}: scene requires unknown {req}")
    for w in c["witnesses"]:
        for q in w["questions"]:
            if q["cat"] not in ("normal", "peripheral", "hidden"): err(f"{cid}: bad cat {q['cat']}")
            if "reveals" in q and q["reveals"] not in w["clues"]: err(f"{cid}: clue {q['reveals']} undefined")
            if q["cat"] == "hidden" and q.get("lie") and "truth" not in q: err(f"{cid}: hidden lie without truth ({q['id']})")
        for k, v in w["clues"].items():
            for s in v.get("supports", []):
                if s not in ids: err(f"{cid}: clue {k} supports unknown {s}")
    if c["yasser_piece"]["evidence_id"] not in items: err(f"{cid}: yasser evidence missing")
    wit_ids = {w["id"] for w in c["witnesses"]}
    scene_ids = {s["id"] for s in c["scenes"]}
    for d in c.get("decisions", []):
        for r in d.get("requires", []):
            if r not in scene_ids | wit_ids: err(f"{cid}: decision {d['id']} requires unknown {r}")
        for o in d["options"]:
            if o["tag"] not in ("legal", "grey", "illegal"): err(f"{cid}: bad tag {o['tag']}")
            if o.get("requires_tool") and o["requires_tool"] not in SHOP["tools"]: err(f"{cid}: unknown tool {o['requires_tool']}")
            ev = o.get("effects", {}).get("evidence")
            if ev:
                for s in ev.get("supports", []):
                    if s not in ids: err(f"{cid}: decision evidence supports unknown {s}")
    if not any(w for w in c["witnesses"]): err(f"{cid}: no witnesses")
    # الملفات تحتاج أدوات يمكن شراؤها
    reveals = {t["reveals"] for t in SHOP["tools"].values()}
    for sc in c["scenes"]:
        for it in sc.get("items", []):
            if it["needs"] != "none" and it["needs"] not in reveals: err(f"{cid}: no shop tool reveals {it['needs']}")
    need = {it["needs"] for sc in c["scenes"] for it in sc.get("items", [])} - {"none"}
    print(f"{cid}: tools needed -> {sorted(need)}")

# مفاتيح الترجمة المستعملة موجودة في loc.gd
loc = open(f"{ROOT}/autoload/loc.gd", encoding="utf8").read()
keys_ar = set(re.findall(r'^\t\t"([a-z_0-9]+)": ', loc.split('"en": {')[0], re.M))
keys_en = set(re.findall(r'^\t\t"([a-z_0-9]+)": ', loc.split('"en": {')[1], re.M))
if keys_ar != keys_en: err(f"ar/en key mismatch: {sorted(keys_ar ^ keys_en)}")
used = set()
for f in glob.glob(f"{ROOT}/scenes/*.gd") + glob.glob(f"{ROOT}/scripts/*.gd"):
    used |= set(re.findall(r'Loc\.(?:t|f)\("([a-z_0-9]+)"', open(f, encoding="utf8").read()))
for k in sorted(used):
    if k.endswith("_"): continue
    if k not in keys_ar: err(f"missing translation: {k}")

# كل مشهد له ملف tscn وملف gd
for gd in glob.glob(f"{ROOT}/scenes/*.gd"):
    if not os.path.exists(gd.replace(".gd", ".tscn")): err(f"no tscn for {gd}")
# كل مشهد يُستدعى بـ Game.goto موجود
for f in glob.glob(f"{ROOT}/scenes/*.gd"):
    for t in re.findall(r'goto\("([a-z_]+)"\)', open(f, encoding="utf8").read()):
        if not os.path.exists(f"{ROOT}/scenes/{t}.tscn"): err(f"{os.path.basename(f)} goes to missing scene {t}")

if errors:
    print("\n".join("ERROR: " + e for e in errors)); sys.exit(1)
print("OK: all data checks passed")
