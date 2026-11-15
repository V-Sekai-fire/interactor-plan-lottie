#!/usr/bin/env python3
"""A Lottie railroad diagram of the whole poseswap domain, in two scenes: the presence slice through the OmniGen2 edit and score, then the AUX route.
Rails are dependencies read from the domain itself (an action that sets a fact, and a later one that reads it), reduced to the shortest rails.
usage: make_poseswap_lottie.py <poseswap domain.jsonld> <aux plan.json> <out.json>"""
import json, sys, math, datetime as dt

W, H, FR = 1680, 720, 30
INK, MUTE, RAIL, BG = (0.13, 0.15, 0.2), (0.45, 0.48, 0.55), (0.80, 0.82, 0.86), (0.985, 0.98, 0.965)
LANE = {"labels": (0.23, 0.51, 0.96), "motion": (0.96, 0.62, 0.04), "hair": (0.06, 0.73, 0.51), "rig": (0.55, 0.36, 0.96),
        "body": (0.23, 0.51, 0.96), "avatar": (0.06, 0.73, 0.51), "edit": (0.55, 0.36, 0.96), "model": (0.96, 0.62, 0.04)}
RED = (0.86, 0.15, 0.15)
tint = lambda c: tuple(1 - 0.30 * (1 - x) for x in c)
dom = json.load(open(sys.argv[1])); aux_plan = json.load(open(sys.argv[2])); ACT = dom["actions"]
reads = lambda a: {b["eval"]["pointer"] for b in ACT[a]["body"] if "eval" in b}
sets = lambda a: {b["pointer/set"] for b in ACT[a]["body"] if "pointer/set" in b}
GPU = {a for a in ACT if "/input/gpu" in reads(a)}
def span(s): return f"{s} s" if s < 60 else f"{s // 60} min" + (f" {s % 60} s" if s % 60 else "")
def secs(iso):
    import re; m = re.match(r"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$", iso or ""); return None if not m else int(m.group(1) or 0) * 3600 + int(m.group(2) or 0) * 60 + int(m.group(3) or 0)
def timing(a):
    d = secs(ACT[a].get("duration"))
    if d is None: return "not timed"
    return span(d) + (" est." if ACT[a].get("duration_basis", "").startswith("estimate") else "")

class Scene:
    def __init__(s, t0, t1): s.t0, s.t1, s.layers = t0, t1, []
    def add(s, l): l.update({"ddd": 0, "ind": 0, "sr": 1, "ao": 0, "ip": s.t0, "op": s.t1, "st": 0, "bm": 0}); s.layers.append(l)
    def lin(s, ts):
        n = len(ts[0][1]); sh = lambda t: round(t + s.t0, 2)
        return {"a": 1, "k": [{"t": sh(t), "s": v, "i": {"x": [1] * n, "y": [1] * n}, "o": {"x": [0] * n, "y": [0] * n}} for t, v in ts[:-1]] + [{"t": sh(ts[-1][0]), "s": ts[-1][1]}]}
    def fade(s, f0, f1, out=None):
        k = [(f0, [0]), (f1, [100])] + ([(out, [100]), (out + 8, [0])] if out else []); return s.lin(k)
still = lambda v: {"a": 0, "k": v}
def ks(p=(0, 0), o=None): return {"o": o or still(100), "r": still(0), "p": still([p[0], p[1], 0]), "a": still([0, 0, 0]), "s": still([100, 100, 100])}
TR = {"ty": "tr", "p": still([0, 0]), "a": still([0, 0]), "s": still([100, 100]), "r": still(0), "o": still(100)}
def rect(S, x, y, w, h, fill, name, r=10, stroke=None, sw=2.5, o=None):
    it = [{"ty": "rc", "d": 1, "s": still([w, h]), "p": still([x + w / 2, y + h / 2]), "r": still(r)}]
    if fill: it.append({"ty": "fl", "c": still(list(fill) + [1]), "o": still(100), "r": 1})
    if stroke: it.append({"ty": "st", "c": still(list(stroke) + [1]), "o": still(100), "w": still(sw), "lc": 2, "lj": 2})
    S.add({"ty": 4, "nm": name, "ks": ks(o=o), "shapes": [{"ty": "gr", "it": it + [TR], "nm": name}]})
def text(S, x, y, t, size, color, name, j=0, o=None):
    d = {"s": size, "f": "Arial", "t": t, "j": j, "tr": 0, "lh": size * 1.25, "ls": 0, "fc": list(color)}
    S.add({"ty": 5, "nm": name, "ks": ks(p=(x, y), o=o), "t": {"d": {"k": [{"s": d, "t": 0}]}, "p": {}, "m": {"g": 1, "a": still([0, 0])}, "a": []}})
def rounded(pts, r=14):
    v, i, o = [pts[0]], [[0, 0]], [[0, 0]]
    for k in range(1, len(pts) - 1):
        p, c, n = pts[k - 1], pts[k], pts[k + 1]; d1, d2 = math.dist(p, c), math.dist(c, n); rr = min(r, d1 / 2, d2 / 2)
        a = [c[0] + (p[0] - c[0]) / d1 * rr, c[1] + (p[1] - c[1]) / d1 * rr]; b = [c[0] + (n[0] - c[0]) / d2 * rr, c[1] + (n[1] - c[1]) / d2 * rr]
        v += [a, b]; i += [[0, 0], [(c[0] - b[0]) * 0.55, (c[1] - b[1]) * 0.55]]; o += [[(c[0] - a[0]) * 0.55, (c[1] - a[1]) * 0.55], [0, 0]]
    v.append(pts[-1]); i.append([0, 0]); o.append([0, 0]); return {"c": False, "v": v, "i": i, "o": o}
def rail(S, path, color, width, name, trim=None, o=None, dash=False):
    it = [{"ty": "sh", "ks": still(path), "nm": "path"}]
    if trim: it.append({"ty": "tm", "s": still(0), "e": S.lin([(trim[0], [0]), (trim[1], [100])]), "o": still(0), "m": 1})
    st = {"ty": "st", "c": still(list(color) + [1]), "o": still(100), "w": still(width), "lc": 1, "lj": 2}
    if dash: st["d"] = [{"n": "d", "nm": "dash", "v": still(9)}, {"n": "g", "nm": "gap", "v": still(7)}]
    S.add({"ty": 4, "nm": name, "ks": ks(o=o), "shapes": [{"ty": "gr", "it": it + [st, TR], "nm": name}]})

def reduce_edges(order, scope, lit_only=None):
    E = {(u, v) for j, v in enumerate(order) for u in order[:j] if sets(u) & reads(v)}
    def reach(u, v, skip):
        stack, seen = [u], set()
        while stack:
            x = stack.pop()
            for (a, b) in E:
                if a == x and (a, b) != skip and b not in seen:
                    if b == v: return True
                    seen.add(b); stack.append(b)
        return False
    return sorted(e for e in E if not reach(e[0], e[1], e))

def draw_scene(S, title, sub, NODES, order, positions, optional, both_lit, NW=134, NH=66, pre_caption=None, caption=None, legend=True, cols=None):
    """NODES: action -> (words, lane, tool). positions: action -> (col, row). optional: drawn dashed and never lit. both_lit: alternatives that are lit together."""
    ROWY = [196 + 76 * r for r in range(7)]; X0 = 50; maxc = max(c for c, _ in positions.values())
    COLP = (W - 2 * X0 - NW) / maxc; pos = {a: (X0 + NW / 2 + positions[a][0] * COLP, ROWY[positions[a][1]]) for a in NODES}
    edges = [e for e in reduce_edges(order, None)]
    PE = [e for e in edges if e[0] not in optional and e[1] not in optional]
    LIGHT, SEND, TRAVEL = 8, 10, 24; lit, arrive = {}, {}
    for a in order:
        if a in optional: continue
        lit[a] = max([arrive[(u, a)] for (u, v) in PE if v == a and (u, a) in arrive] or [44])
        for (u, v) in PE:
            if u == a: arrive[(u, v)] = lit[a] + SEND + TRAVEL
    end = max(lit.values()) + LIGHT
    def route(u, v):
        (xu, yu), (xv, yv) = pos[u], pos[v]; s = (xu + NW / 2, yu); t = (xv - NW / 2, yv)
        return [list(s), list(t)] if yu == yv else [list(s), [t[0] - 20, yu], [t[0] - 20, yv], list(t)]
    rect(S, 0, 0, W, H, BG, "background", r=0)
    text(S, 40, 50, title, 30, INK, "title", o=S.fade(0, 14)); text(S, 40, 80, sub, 15, MUTE, "subtitle", o=S.fade(6, 20))
    if legend:
        lx = 40
        for lane, label in legend:
            rect(S, lx, 104, 14, 14, LANE[lane], f"legend {lane}", r=3, o=S.fade(10, 24)); text(S, lx + 22, 116, label, 14, INK, f"legend {lane} text", o=S.fade(10, 24)); lx += 44 + 8 * len(label)
        rect(S, lx, 104, 14, 14, (1, 1, 1), "legend gpu", r=3, stroke=RED, sw=2, o=S.fade(10, 24)); text(S, lx + 22, 116, "red outline: the one GPU", 14, INK, "legend gpu text", o=S.fade(10, 24))
    paths = {e: rounded(route(*e)) for e in edges}
    for e in edges: rail(S, paths[e], RAIL, 4, f"rail {e}", o=S.fade(10, 30), dash=e not in PE)
    for e in PE: rail(S, paths[e], LANE[NODES[e[0]][1]], 4, f"travel {e}", trim=(lit[e[0]] + SEND, lit[e[0]] + SEND + TRAVEL))
    for (u, v) in edges:
        tx, ty = route(u, v)[-1]; tri = {"c": True, "v": [[tx, ty], [tx - 9, ty - 6], [tx - 9, ty + 6]], "i": [[0, 0]] * 3, "o": [[0, 0]] * 3}
        S.add({"ty": 4, "nm": f"arrow {u}", "ks": ks(o=S.fade(10, 30)), "shapes": [{"ty": "gr", "nm": "arrow", "it": [{"ty": "sh", "ks": still(tri)}, {"ty": "fl", "c": still(list(MUTE) + [1]), "o": still(100), "r": 1}, TR]}]})
    for a in NODES:
        (x, y), (words, lane, tool) = pos[a], NODES[a]; skipped = a in optional; edge = RED if a in GPU else (0.62, 0.65, 0.7)
        rect(S, x - NW / 2, y - NH / 2, NW, NH, (1, 1, 1) if not skipped else (0.95, 0.95, 0.93), f"node {a}", stroke=edge, o=S.fade(8, 22))
        if not skipped: rect(S, x - NW / 2, y - NH / 2, NW, NH, tint(LANE[lane]), f"lit {a}", stroke=RED if a in GPU else LANE[lane], o=S.lin([(lit[a], [0]), (lit[a] + LIGHT, [100])]))
        sh = MUTE if skipped else INK
        text(S, x, y - 10, words, 14, sh, f"name {a}", j=2, o=S.fade(12, 26)); text(S, x, y + 6, tool, 11, MUTE, f"tool {a}", j=2, o=S.fade(12, 26)); text(S, x, y + 22, timing(a), 12, MUTE, f"time {a}", j=2, o=S.fade(12, 26))
        if a in GPU: text(S, x + NW / 2 - 6, y - NH / 2 - 4, "GPU", 11, RED, f"gpu {a}", j=1, o=S.fade(12, 26))
    return pos, end, PE, lit, paths

layers_all = []
# ======================= scene 1: the presence slice, the relay, the edit and the score
S1 = Scene(0, 0)
N1 = {
 "fetch-clips": ("Fetch motion clips", "body", "muscle-drive release"), "encode-packets": ("Encode to packets", "body", "packets-guest"),
 "route-model": ("Route: model", "body", "zone-router-guest"), "route-relay": ("Route: relay", "body", "transport-zone-relay (C)"),
 "seal-and-take": ("Seal and take", "body", "observer-guest"), "judge": ("Judge", "body", "observer-guest"),
 "agree": ("Agree", "body", "replica-guest, 4 copies"), "skip-agree": ("Skip agreeing", "body", "pass through"),
 "play-curve": ("Play the curve", "body", "curve-guest"), "fit-anny": ("Fit the avatar", "avatar", "anny-fit-guest"),
 "follow": ("Avatar follows", "avatar", "anny-follow-guest"), "snapshot": ("Take a snapshot", "avatar", "presence-gates"),
 "load-omnigen2-transformer": ("Load OmniGen2", "model", "transformer"), "load-editscore-lora": ("Load EditScore", "model", "LoRA"),
 "merge-editscore-lora": ("Merge the LoRA", "model", "into OmniGen2"), "load-qwen25vl-conditioner": ("Load Qwen2.5-VL", "model", "conditioner"),
 "load-omnigen2-vae": ("Load the VAE", "model", "OmniGen2"), "edit": ("Edit the snapshot", "edit", "OmniGen2 + EditScore"),
 "score": ("Score the edit", "edit", "EditScore"), "check-mul-mat": ("Check mul_mat", "edit", "Lean guest")}
P1 = {"fetch-clips": (0, 0), "encode-packets": (1, 0), "route-model": (2, 0), "route-relay": (2, 1), "seal-and-take": (3, 0), "judge": (4, 0), "agree": (5, 0), "skip-agree": (5, 1),
      "play-curve": (6, 0), "fit-anny": (6, 1), "follow": (7, 0), "snapshot": (8, 0), "edit": (9, 0), "score": (10, 0),
      "load-omnigen2-transformer": (4, 3), "load-editscore-lora": (4, 4), "merge-editscore-lora": (6, 3), "load-qwen25vl-conditioner": (7, 3), "load-omnigen2-vae": (8, 3), "check-mul-mat": (10, 4)}
O1 = ["fetch-clips", "encode-packets", "route-model", "route-relay", "seal-and-take", "judge", "agree", "skip-agree", "play-curve", "fit-anny", "follow", "snapshot",
      "load-omnigen2-transformer", "load-editscore-lora", "merge-editscore-lora", "load-qwen25vl-conditioner", "load-omnigen2-vae", "edit", "score", "check-mul-mat"]
assert set(O1) == set(N1) == set(P1), (set(O1) ^ set(N1), set(N1) ^ set(P1))
pos1, end1, PE1, lit1, _ = draw_scene(S1, "Part 1. From a moving body to an edited, scored image",
    "Each box waits for the rails into it. Two ways to route (the model or the relay) and two ways to agree (replicas or pass through) are both drawn.",
    N1, O1, P1, set(), set(),
    legend=[("body", "the body's packets"), ("avatar", "the avatar"), ("model", "load the edit models"), ("edit", "edit and score")])
cap_y = 196 + 76 * 5 + 10
text(S1, 40, cap_y, "The relay is transport-zone-relay: a C state machine equal to the router model, on two UDP sockets and a 64 Hz tick.", 15, INK, "cap1", o=S1.fade(end1 + 4, end1 + 18))
text(S1, 40, cap_y + 24, "Every box also needs its own repository to pass its gate (not drawn). Most of this slice has not been timed; only the loads, the edit and the score have.", 15, MUTE, "cap2", o=S1.fade(end1 + 10, end1 + 24))
text(S1, 40, cap_y + 48, "Next, inside the relay, then the AUX route: from an image or a mesh to labelled, rigged garment parts.", 15, INK, "cap3", o=S1.fade(end1 + 16, end1 + 30))
T1 = end1 + 80                                      # scene 1 lasts as long as its traversal plus a pause for the captions
for l in S1.layers: l["op"] = T1
layers_all += list(reversed(S1.layers))


# ======================= scene: inside the relay (transport-zone-relay, docs/zone-net.md and docs/zone-relay.md)
SL = Scene(T1, 0); NWL, NHL = 150, 76; AMB = (0.96, 0.62, 0.04); GRN = (0.06, 0.73, 0.51); BLU = LANE["body"]
LN = {"clients": (110, 190, "Clients send", "two frames every", "6 ticks"), "ports": (110, 300, "Two UDP ports", "PORT: parts 0-11", "PORT+1: parts 12-20"),
      "drain": (330, 300, "Drain the sockets", "recvmmsg, up to 32", "datagrams at a time"), "who": (620, 300, "Who sent it?", "source address = person", "zone = person / 4"),
      "put": (910, 300, "Offer the frame", "zr_put: 1 in 5 ticks,", "a burst of two"), "send": (1200, 300, "Send to the other 3", "sendmmsg, from the", "port of the same half"),
      "tick": (1200, 520, "Tick every zone", "now + 1; a slot silent", "192 ticks is emptied"), "catch": (910, 520, "Catch up if late", "one tick for each tick", "the wall has had"),
      "wait": (620, 520, "Wait for the tick", "64 Hz: one tick is", "1.5625e-2 s"), "refused": (910, 190, "Refused, counted", "too long, a 5th person,", "or a half taken too soon")}
L = lambda k: LN[k]
top = lambda k: (L(k)[0], L(k)[1] - NHL / 2); bot = lambda k: (L(k)[0], L(k)[1] + NHL / 2)
rgt = lambda k: (L(k)[0] + NWL / 2, L(k)[1]); lft = lambda k: (L(k)[0] - NWL / 2, L(k)[1])
EL = [("clients", "ports", [bot("clients"), top("ports")], BLU, None), ("ports", "drain", [rgt("ports"), lft("drain")], BLU, None),
      ("drain", "who", [rgt("drain"), lft("who")], BLU, None), ("who", "put", [rgt("who"), lft("put")], BLU, None),
      ("put", "send", [rgt("put"), lft("send")], BLU, "taken"), ("send", "tick", [bot("send"), top("tick")], BLU, None),
      ("tick", "catch", [lft("tick"), rgt("catch")], BLU, None), ("catch", "wait", [lft("catch"), rgt("wait")], BLU, None),
      ("wait", "drain", [lft("wait"), (L("drain")[0], L("wait")[1]), bot("drain")], GRN, "next tick"),
      ("put", "refused", [top("put"), bot("refused")], AMB, "refused"), ("refused", "tick", [rgt("refused"), (1390, L("refused")[1]), (1390, L("tick")[1]), rgt("tick")], AMB, None)]
TRAV, SND = 22, 10; litL = {"clients": 40}; start = {}
for (a, b, pts, col, lab) in EL[:9]:
    start[(a, b)] = litL[a] + SND
    if b not in litL: litL[b] = start[(a, b)] + TRAV
loop_back_end = start[("wait", "drain")] + TRAV
start[("put", "refused")] = loop_back_end + 20; litL["refused"] = start[("put", "refused")] + TRAV
start[("refused", "tick")] = litL["refused"] + SND; endL = start[("refused", "tick")] + TRAV + 8
rect(SL, 0, 0, W, H, BG, "background", r=0)
text(SL, 40, 50, "Inside the relay: one loop, 64 times a second", 30, INK, "title", o=SL.fade(0, 14))
text(SL, 40, 80, "transport-zone-relay, in C. Strict C99, no heap, and it never reads a byte of a frame. A zone is four people; a frame is 1,200 bytes.", 15, MUTE, "subtitle", o=SL.fade(6, 20))
for (a, b, pts, col, lab) in EL:
    pth = rounded([list(p) for p in pts]); rail(SL, pth, RAIL, 4, f"rail {a} {b}", o=SL.fade(10, 30), dash=(col == AMB))
    rail(SL, pth, col, 4, f"travel {a} {b}", trim=(start[(a, b)], start[(a, b)] + TRAV))
    (x1, y1), (x2, y2) = pts[-2], pts[-1]; dl = math.hypot(x2 - x1, y2 - y1); dx, dy = (x2 - x1) / dl, (y2 - y1) / dl
    tri = {"c": True, "v": [[x2, y2], [x2 - 9 * dx - 6 * dy, y2 - 9 * dy + 6 * dx], [x2 - 9 * dx + 6 * dy, y2 - 9 * dy - 6 * dx]], "i": [[0, 0]] * 3, "o": [[0, 0]] * 3}
    SL.add({"ty": 4, "nm": f"arrow {a} {b}", "ks": ks(o=SL.fade(10, 30)), "shapes": [{"ty": "gr", "nm": "arrow", "it": [{"ty": "sh", "ks": still(tri)}, {"ty": "fl", "c": still(list(MUTE) + [1]), "o": still(100), "r": 1}, TR]}]})
    if lab:
        lp = {"taken": ((rgt("put")[0] + lft("send")[0]) / 2, L("put")[1] - 8), "refused": (L("put")[0] + 8, (top("put")[1] + bot("refused")[1]) / 2 + 4), "next tick": ((lft("wait")[0] + L("drain")[0]) / 2 - 18, L("wait")[1] - 8)}[lab]
        text(SL, lp[0], lp[1], lab, 12, col if col != BLU else INK, f"label {lab}", j=1 if lab == "refused" else 2, o=SL.fade(12, 30))
for k, (x, y, name, l1, l2) in LN.items():
    col = AMB if k == "refused" else BLU; edge = (0.62, 0.65, 0.7)
    rect(SL, x - NWL / 2, y - NHL / 2, NWL, NHL, (1, 1, 1), f"node {k}", stroke=edge, o=SL.fade(8, 22))
    rect(SL, x - NWL / 2, y - NHL / 2, NWL, NHL, tint(col), f"lit {k}", stroke=col, o=SL.lin([(litL[k], [0]), (litL[k] + 8, [100])]))
    text(SL, x, y - 14, name, 14, INK, f"name {k}", j=2, o=SL.fade(12, 26)); text(SL, x, y + 4, l1, 11, MUTE, f"l1 {k}", j=2, o=SL.fade(12, 26)); text(SL, x, y + 18, l2, 11, MUTE, f"l2 {k}", j=2, o=SL.fade(12, 26))
for i, t in enumerate(["Measured at 256 people", "Linux, two shared vCPUs,", "loopback, two runs:", "median tick 1.625e-3 s", "and 1.655e-3 s", "99th percentile 2.43e-3 s", "and 2.33e-3 s", "per datagram out 4.626e-6 s", "and 4.659e-6 s", "The budget aimed at is", "4e-3 s (RFD66606-2442),", "not a gate"]):
    text(SL, 1440, 250 + 22 * i, t, 14 if i == 0 else 13, INK if i == 0 else MUTE, f"stat {i}", o=SL.fade(14, 30))
text(SL, 40, 628, "A taken frame is copied in and handed out unchanged, and sent on as it arrives, so none waits in the relay longer than one tick.", 16, INK, "cap1", o=SL.fade(endL, endL + 14))
text(SL, 40, 654, "A viewer gets six frames a send interval: two from each of the three others. A frame that comes too soon is refused and counted, and its bytes are not copied.", 15, MUTE, "cap2", o=SL.fade(endL + 6, endL + 20))
text(SL, 40, 680, "Checked against the router model's recorded trace (210 ticks). The sockets are checked on loopback on one machine only; no real network.", 15, MUTE, "cap3", o=SL.fade(endL + 12, endL + 26))
TL = T1 + endL + 100
for l in SL.layers: l["op"] = TL
layers_all += list(reversed(SL.layers))

# ======================= scene 2: the AUX route, from its own plan
S2 = Scene(TL, 0)
def stamp(s): return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
origin = stamp(aux_plan["temporal"]["origin"]); order2 = []; win = {}
for st in aux_plan["steps"]:
    if st["action"] not in win: order2.append(st["action"]); win[st["action"]] = (int((stamp(st["start"]) - origin).total_seconds()), int((stamp(st["end"]) - origin).total_seconds()))
N2 = {
 "relabel-coco": ("Regroup photo labels", "labels", "COCO, 7 part types"), "make-synth-set": ("Render practice images", "labels", "Mitsuba 3"),
 "train-part-detector": ("Train part detector", "labels", "RF-DETR"), "segment-labels": ("Label each part", "labels", "Alchemy3D-Segment"),
 "restore-units": ("Undo the scaling", "labels", "units.py"), "close-labelling": ("Labels finished", "labels", ""),
 "use-dataset-mesh": ("Use dataset mesh", "labels", "GarmentCode"), "ingest-usd": ("Load mesh", "labels", "OpenUSD"),
 "unitise-source": ("Scale to unit cube", "labels", "units.py"), "write-scale-sidecar": ("Save the scale", "labels", "units.py"),
 "matte-image": ("Matte the image", "labels", "BiRefNet HR"), "pixal3d-image-to-mesh": ("Image to mesh", "labels", "Pixal3D on TRELLIS.2"),
 "build-warp": ("Build cloth simulator", "motion", "Warp"), "measure-motion-lag": ("Measure part lag", "motion", "Warp, not run yet"),
 "classify-soft-rigid": ("Soft or rigid?", "motion", "not built yet"), "rig-aux-parts": ("Rig the parts", "rig", "not built yet"),
 "make-hair-cards": ("Make hair cards", "hair", "HairDeck"), "make-spring-chains": ("Make spring chains", "hair", "HairDeck")}
R2 = {"relabel-coco": 0, "make-synth-set": 1, "train-part-detector": 1, "segment-labels": 1, "restore-units": 1, "close-labelling": 1, "use-dataset-mesh": 2, "ingest-usd": 2, "unitise-source": 2,
      "write-scale-sidecar": 2, "matte-image": 3, "pixal3d-image-to-mesh": 3, "build-warp": 4, "measure-motion-lag": 4, "classify-soft-rigid": 4, "rig-aux-parts": 4, "make-hair-cards": 5, "make-spring-chains": 5}
ALT = [a for a in N2 if a not in win]; assert set(order2) | set(ALT) == set(N2), (set(order2) | set(ALT)) ^ set(N2)
full = order2[:order2.index("ingest-usd")] + ALT + order2[order2.index("ingest-usd"):]
E = reduce_edges(full, None); E = [e for e in E if not (e[1] in ALT and e[0] not in ALT)]
depth = {}
for a in full: depth[a] = 1 + max([depth[u] for (u, v) in E if v == a] or [-1])
P2 = {a: (depth[a], R2[a]) for a in N2}
dur2 = {a: win[a][1] - win[a][0] for a in order2}
PE2 = [e for e in E if e[0] not in ALT and e[1] not in ALT]; best = {}
for a in order2: best[a] = dur2[a] + max([best[u] for (u, v) in PE2 if v == a] or [0])
tail = max(order2, key=lambda a: best[a]); crit = [tail]
while True:
    prev = [u for (u, v) in PE2 if v == crit[0] and best[u] + dur2[crit[0]] == best[crit[0]]]
    if not prev: break
    crit.insert(0, prev[0])
pos2, end2, PE2b, lit2, paths2 = draw_scene(S2, "Part 2. From an image or a mesh to rigged garment parts",
    "The planner's route for the AUX goal. A step starts when everything feeding it has finished. Dashed is the other way to get a mesh.",
    N2, full, P2, set(ALT), set(),
    legend=[("labels", "find and label the parts"), ("motion", "learn which parts move"), ("hair", "hair and tail chains"), ("rig", "rig the parts")])
CF = end2 + 24
for (u, v) in zip(crit, crit[1:]):
    (xu, yu), (xv, yv) = pos2[u], pos2[v]; s = (xu + 67, yu); t = (xv - 67, yv)
    pts = [list(s), list(t)] if yu == yv else [list(s), [t[0] - 20, yu], [t[0] - 20, yv], list(t)]; rail(S2, rounded(pts), RED, 8, f"critical {u} {v}", o=S2.lin([(CF, [0]), (CF + 14, [100])]))
text(S2, 40, 648, f"Longest chain, in red: {' > '.join(N2[a][0].lower().rstrip('?') for a in crit)}. It sets the {best[tail] // 60} minutes.", 16, INK, "cap1", o=S2.lin([(CF + 4, [0]), (CF + 22, [100])]))
text(S2, 40, 674, "The total leaves out the image-to-mesh steps and the presence slice: none of them has been timed.", 15, MUTE, "cap2", o=S2.lin([(CF + 10, [0]), (CF + 28, [100])]))
OP = TL + end2 + 100
for l in S2.layers: l["op"] = OP
layers_all += list(reversed(S2.layers))

for i, l in enumerate(layers_all): l["ind"] = i + 1
json.dump({"v": "5.7.0", "fr": FR, "ip": 0, "op": OP, "w": W, "h": H, "nm": "poseswap plan, as a railroad diagram", "ddd": 0, "assets": [],
           "fonts": {"list": [{"fName": "Arial", "fFamily": "Arial", "fStyle": "Regular", "ascent": 71.6}]}, "layers": layers_all, "markers": []}, open(sys.argv[3], "w"), separators=(",", ":"))
print("wrote", sys.argv[3], len(layers_all), "layers,", round(OP / FR, 1), "s; scene 1 ends at frame", T1, "; scene 2 lit by frame", TL + end2, "; critical", " > ".join(crit), best[tail], "s")
