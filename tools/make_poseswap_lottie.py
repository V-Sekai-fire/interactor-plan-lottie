#!/usr/bin/env python3
"""A Lottie of the poseswap plan drawn like Unreal Engine Blueprints: nodes with exec pins (white, the sequence) and data pins (coloured, inputs on the left, outputs on the right).
Scenes 1 and 3 are read from the domain: a data pin is a fact a step reads or sets, a data wire joins the step that sets it to the one that reads it, and the white exec wire is the
planner's step order (alternatives are Branch nodes). Scene 2 is the relay loop, drawn by hand from transport-zone-relay's docs.
usage: make_poseswap_lottie.py <domain.jsonld> <aux plan.json> <out.json>"""
import json, sys, math, re

W, H, FR = 1680, 720, 30
BGC, GRID1, GRID2 = (0.085, 0.085, 0.095), (0.115, 0.115, 0.125), (0.15, 0.15, 0.165)
BODY, EDGE, TXT, SUB = (0.155, 0.155, 0.168), (0.04, 0.04, 0.045), (0.86, 0.86, 0.88), (0.62, 0.62, 0.66)
WHITE, RED = (0.97, 0.97, 0.97), (0.9, 0.2, 0.2)
HDR = {"labels": (0.12, 0.33, 0.62), "motion": (0.66, 0.38, 0.08), "hair": (0.13, 0.46, 0.27), "rig": (0.42, 0.24, 0.62), "body": (0.12, 0.33, 0.62), "avatar": (0.1, 0.46, 0.44),
       "model": (0.66, 0.38, 0.08), "edit": (0.42, 0.24, 0.62), "event": (0.62, 0.1, 0.1), "branch": (0.32, 0.32, 0.36), "macro": (0.3, 0.3, 0.34)}
PIN = {"body": (0.1, 0.8, 0.66), "avatar": (0.36, 0.66, 1.0), "image": (1.0, 0.46, 0.76), "model": (1.0, 0.8, 0.22), "aux": (0.46, 0.9, 0.4), "gpu": (0.9, 0.2, 0.2), "op": (0.8, 0.6, 1.0),
       "input": (0.6, 0.6, 0.66), "struct": (0.0, 0.46, 0.95), "int": (0.1, 0.8, 0.66), "bool": (0.85, 0.15, 0.15)}
dom = json.load(open(sys.argv[1])); aux_plan = json.load(open(sys.argv[2])); ACT = dom["actions"]
reads = lambda a: [b["eval"]["pointer"] for b in ACT[a]["body"] if "eval" in b]
sets = lambda a: [b["pointer/set"] for b in ACT[a]["body"] if "pointer/set" in b]
def span(s): return f"{s} s" if s < 60 else f"{s // 60} min" + (f" {s % 60} s" if s % 60 else "")
def secs(iso):
    m = re.match(r"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$", iso or ""); return None if not m else int(m.group(1) or 0) * 3600 + int(m.group(2) or 0) * 60 + int(m.group(3) or 0)
def timing(a):
    d = secs(ACT[a].get("duration"))
    return "not timed" if d is None else span(d) + (" est." if ACT[a].get("duration_basis", "").startswith("estimate") else "")
def pin_type(f): return "gpu" if f == "/input/gpu" else f.split("/")[1]
def label(f): return "GPU" if f == "/input/gpu" else f.split("/")[-1]

still = lambda v: {"a": 0, "k": v}
TR = {"ty": "tr", "p": still([0, 0]), "a": still([0, 0]), "s": still([100, 100]), "r": still(0), "o": still(100)}
class Scene:
    def __init__(s, t0): s.t0, s.t1, s.layers = t0, 0, []
    def add(s, l): l.update({"ddd": 0, "ind": 0, "sr": 1, "ao": 0, "ip": s.t0, "op": 0, "st": 0, "bm": 0}); s.layers.append(l); return l
    def lin(s, ts, ease=False):
        n = len(ts[0][1]); sh = lambda t: round(t + s.t0, 2)
        ox, oy, ix, iy = ([0.33] * n, [0] * n, [0.67] * n, [1] * n) if ease else ([0] * n, [0] * n, [1] * n, [1] * n)
        return {"a": 1, "k": [{"t": sh(t), "s": v, "i": {"x": ix, "y": iy}, "o": {"x": ox, "y": oy}} for t, v in ts[:-1]] + [{"t": sh(ts[-1][0]), "s": ts[-1][1]}]}
    def fade(s, f0, f1): return s.lin([(f0, [0]), (f1, [100])])
def ks(p=(0, 0), o=None): return {"o": o or still(100), "r": still(0), "p": still([p[0], p[1], 0]), "a": still([0, 0, 0]), "s": still([100, 100, 100])}
def grp(items, nm="g"): return {"ty": "gr", "nm": nm, "it": items + [TR]}
def rc(x, y, w, h, fill, r=6, stroke=None, sw=1.2):
    it = [{"ty": "rc", "d": 1, "s": still([w, h]), "p": still([x + w / 2, y + h / 2]), "r": still(r)}]
    if fill: it.append({"ty": "fl", "c": still(list(fill) + [1]), "o": still(100), "r": 1})
    if stroke: it.append({"ty": "st", "c": still(list(stroke) + [1]), "o": still(100), "w": still(sw), "lc": 2, "lj": 2})
    return grp(it, "rect")
def circle(x, y, r, color, filled):
    it = [{"ty": "el", "s": still([2 * r, 2 * r]), "p": still([x, y])}, {"ty": "st", "c": still(list(color) + [1]), "o": still(100), "w": still(1.8), "lc": 2, "lj": 2}]
    if filled: it.append({"ty": "fl", "c": still(list(color) + [1]), "o": still(100), "r": 1})
    return grp(it, "pin")
def execpin(x, y, filled):
    pts = [[x - 5, y - 6], [x + 2, y - 6], [x + 7, y], [x + 2, y + 6], [x - 5, y + 6]]
    it = [{"ty": "sh", "ks": still({"c": True, "v": pts, "i": [[0, 0]] * 5, "o": [[0, 0]] * 5})}, {"ty": "st", "c": still(list(WHITE) + [1]), "o": still(100), "w": still(1.8), "lc": 2, "lj": 2}]
    if filled: it.append({"ty": "fl", "c": still(list(WHITE) + [1]), "o": still(100), "r": 1})
    return grp(it, "exec")
def bez(p1, p2):
    d = max(50, abs(p2[0] - p1[0]) * 0.5); return {"c": False, "v": [list(p1), list(p2)], "i": [[0, 0], [-d, 0]], "o": [[d, 0], [0, 0]]}
def wire(S, p1, p2, color, width, t0, t1, name, dash=False, base=None):
    it = [{"ty": "sh", "ks": still(bez(p1, p2)), "nm": "path"}, {"ty": "tm", "s": still(0), "e": S.lin([(t0, [0]), (t1, [100])]), "o": still(0), "m": 1}]
    st = {"ty": "st", "c": still(list(color) + [1]), "o": still(100), "w": still(width), "lc": 2, "lj": 2}
    if dash: st["d"] = [{"n": "d", "nm": "dash", "v": still(8)}, {"n": "g", "nm": "gap", "v": still(6)}]
    S.add({"ty": 4, "nm": name, "ks": ks(), "shapes": [grp(it + [st], name)]})
def text(S, x, y, t, size, color, name, j=0, o=None):
    d = {"s": size, "f": "Arial", "t": t, "j": j, "tr": 0, "lh": size * 1.25, "ls": 0, "fc": list(color)}
    S.add({"ty": 5, "nm": name, "ks": ks(p=(x, y), o=o), "t": {"d": {"k": [{"s": d, "t": 0}]}, "p": {}, "m": {"g": 1, "a": still([0, 0])}, "a": []}})

NW, HH, ROW = 210, 28, 20
class Node:
    def __init__(n, S, key, x, y, title, sub, kind, ins, outs, exec_in=True, exec_outs=("",), desk=0, dim=False):
        n.key, n.x, n.y, n.kind, n.dim = key, x, y, kind, dim; sh = 14 if sub else 0
        n.head = HH + sh; rows = max(len(ins), len(outs), 0) + (1 if desk else 0)
        n.h = n.head + 8 + max(len(exec_outs), 1) * 20 + rows * ROW + 8; n.ins, n.outs, n.exec_outs, n.exec_in = ins, outs, list(exec_outs), exec_in
        n.pin_in, n.pin_out, n.xo = {}, {}, {}
        n.title, n.sub, n.desk, n.S = title, sub, desk, S
    def anchors(n):
        y0 = n.y + n.head + 8 + max(len(n.exec_outs), 1) * 20
        n.exec_in_pos = (n.x + 12, n.y + n.head + 18)
        n.exec_out_pos = [(n.x + NW - 12, n.y + n.head + 18 + 20 * i) for i in range(len(n.exec_outs))]
        for i, (k, t) in enumerate(n.ins): n.pin_in[k] = (n.x + 12, y0 + 10 + i * ROW)
        for i, (k, t) in enumerate(n.outs): n.pin_out[k] = (n.x + NW - 12, y0 + 10 + i * ROW)
    def draw(n, wired_in, wired_out, t_lit, exec_in_wired, exec_out_wired):
        S, a = n.S, 1.0 if not n.dim else 0.55; n.anchors(); col = HDR[n.kind]
        items = [rc(n.x, n.y, NW, n.h, BODY, 7, EDGE, 1.4), rc(n.x, n.y, NW, n.head, col, 7), rc(n.x, n.y + n.head - 8, NW, 8, col, 0)]
        if n.exec_in is not False: items.append(execpin(*n.exec_in_pos, exec_in_wired))
        for i, name in enumerate(n.exec_outs): items.append(execpin(*n.exec_out_pos[i], exec_out_wired[i]))
        for (k, t) in n.ins: items.append(circle(*n.pin_in[k], 4.5, PIN[t], k in wired_in))
        for (k, t) in n.outs: items.append(circle(*n.pin_out[k], 4.5, PIN[t], k in wired_out))
        S.add({"ty": 4, "nm": f"node {n.key}", "ks": ks(o=S.lin([(8, [0]), (22, [100 * a])])), "shapes": items[::-1]})   # Lottie paints the first group on top
        if t_lit is not None:                                        # the node runs: its outline and header flash
            S.add({"ty": 4, "nm": f"flash {n.key}", "ks": ks(o=S.lin([(t_lit, [0]), (t_lit + 5, [100]), (t_lit + 30, [0])])), "shapes": [rc(n.x, n.y, NW, n.head, (1, 1, 1), 7), rc(n.x, n.y, NW, n.h, None, 7, WHITE, 2.6)]})
            S.layers[-1]["shapes"][0]["it"][1]["o"] = still(18)
        fo = S.fade(12, 26)
        text(S, n.x + 10, n.y + 19, n.title, 14, (1, 1, 1), f"ntitle {n.key}", o=fo)
        if n.sub: text(S, n.x + 10, n.y + 34, n.sub, 10.5, (0.88, 0.88, 0.9), f"nsub {n.key}", o=fo)
        for i, name in enumerate(n.exec_outs):
            if name: text(S, n.x + NW - 24, n.y + n.head + 22 + 20 * i, name, 11, TXT, f"exec {n.key} {i}", j=1, o=fo)
        for (k, t) in n.ins: text(S, n.pin_in[k][0] + 12, n.pin_in[k][1] + 4, label(k), 11, TXT, f"in {n.key} {k}", o=fo)
        for (k, t) in n.outs: text(S, n.pin_out[k][0] - 12, n.pin_out[k][1] + 4, label(k), 11, TXT, f"out {n.key} {k}", j=1, o=fo)
        if n.desk: text(S, n.x + 12, n.y + n.h - 10, f"+ {n.desk} stated by the desk", 10, SUB, f"desk {n.key}", o=fo)

def run_scene(S, nodes, exec_edges, order, data_edges, title, sub, caps, step=17, extra=None):
    """nodes: key -> Node. exec_edges: (src, out_index, dst). order: keys in the order they run. data_edges: (src, fact, dst, fact, dashed)."""
    for k in order: pass
    T0 = 36; lit = {k: T0 + i * step for i, k in enumerate(order)}
    ein = {k: set() for k in nodes}; eout = {k: [False] * len(nodes[k].exec_outs) for k in nodes}; win = {k: set() for k in nodes}; wout = {k: set() for k in nodes}
    for (s, i, d) in exec_edges: ein[d].add(s); eout[s][i] = True
    for (s, f, d, g, dash) in data_edges: wout[s].add(f); win[d].add(g)
    grid_bg(S)
    for (s, f, d, g, dash) in data_edges:                                                   # wires under the nodes
        ps, pd = nodes[s].pin_out_pos(f), nodes[d].pin_in_pos(g)
        t = pin_type_for(nodes[s], f); wire(S, ps, pd, PIN[t], 2.4, lit[s] + 6, lit[s] + 26, f"data {s} {f} {d}", dash=dash)
    for (s, i, d) in exec_edges:
        wire(S, nodes[s].exec_out_pos[i], nodes[d].exec_in_pos, WHITE, 3.2, lit.get(d, T0) - 16, lit.get(d, T0) - 2, f"exec {s} {d}", dash=(s in nodes and nodes[s].dim) or nodes[d].dim)
    for k, n in nodes.items(): n.draw(win[k], wout[k], lit.get(k) if not n.dim else None, bool(ein[k]), eout[k])
    if extra: extra(S, nodes, lit)
    # the camera: a null that moves the graph so the running node stays in view
    cam = []; cx = cy = None
    for k in order:
        n = nodes[k]; tx = min(max(n.x + NW / 2 - 760, 0), CAMX[0]); ty = min(max(n.y + n.h / 2 - 270, 0), CAMX[1]); cam.append((lit[k] - 10, [40 - tx, 150 - ty, 0]))
    cam = [(0, cam[0][1])] + cam
    S.add({"ty": 3, "nm": "camera", "ks": {"o": still(100), "r": still(0), "p": S.lin(cam, ease=True), "a": still([0, 0, 0]), "s": still([100, 100, 100])}})
    end = lit[order[-1]] + 40
    return lit, end

def grid_bg(S):
    S.add({"ty": 4, "nm": "background", "ks": ks(), "shapes": [rc(0, 0, W, H, BGC, 0)]})
    for step, col, wd, nm in ((20, GRID1, 1, "grid fine"), (100, GRID2, 1.5, "grid bold")):
        for ax in ("v", "h"):
            n = (W if ax == "v" else H) // step + 1
            rect = {"ty": "rc", "d": 1, "s": still([wd, H] if ax == "v" else [W, wd]), "p": still([0, H / 2] if ax == "v" else [W / 2, 0]), "r": still(0)}
            rp = {"ty": "rp", "c": still(n), "o": still(0), "m": 0, "tr": {"ty": "tr", "p": still([step, 0] if ax == "v" else [0, step]), "a": still([0, 0]), "s": still([100, 100]), "r": still(0), "so": still(100), "eo": still(100)}}
            S.add({"ty": 4, "nm": f"{nm} {ax}", "ks": ks(), "shapes": [{"ty": "gr", "nm": nm, "it": [rect, {"ty": "fl", "c": still(list(col) + [1]), "o": still(100), "r": 1}, rp, TR]}]})
def overlay(S, title, sub, caps, t_caps):
    S.add({"ty": 4, "nm": "title strip", "ks": ks(), "shapes": [rc(0, 0, W, 112, (0.05, 0.05, 0.057), 0)]})
    text(S, 40, 52, title, 30, (1, 1, 1), "title", o=S.fade(0, 14)); text(S, 40, 82, sub, 15, SUB, "subtitle", o=S.fade(6, 20))
    S.add({"ty": 4, "nm": "caption strip", "ks": ks(o=S.fade(t_caps, t_caps + 12)), "shapes": [rc(0, H - 100, W, 100, (0.05, 0.05, 0.057), 0)]})
    for i, (t, c) in enumerate(caps): text(S, 40, H - 70 + 26 * i, t, 15, c, f"caption {i}", o=S.fade(t_caps + 4 * i, t_caps + 16 + 4 * i))
CAMX = [0, 0]
def pin_type_for(n, f): return dict(n.outs)[f]
Node.pin_out_pos = lambda n, f: n.pin_out[f]; Node.pin_in_pos = lambda n, f: n.pin_in[f]

def build_nodes(S, spec, order_all):
    """spec: key -> dict(x, y, title, sub, kind, exec_outs, dim). Pins are the facts the step reads and sets, wired when another step sets them."""
    nodes = {}; data_edges = []; real = [k for k in order_all if k in ACT]
    wired_reads = {k: [] for k in real}; produced = {}
    for i, v in enumerate(real):
        for f in reads(v):
            prior = [u for u in real[:i] if f in sets(u)]
            if prior:
                last = prior[-1]; group = [u for u in prior if u in ALTGRP.get(last, ())] if last in ALTGRP else []
                for u in dict.fromkeys(group + [last]): data_edges.append((u, f, v, f, u != last)); wired_reads[v].append(f)
    ins = {v: [(f, pin_type(f)) for f in dict.fromkeys(wired_reads[v])] for v in real}
    outs = {u: [(f, pin_type(f)) for f in sets(u) if any(e[0] == u and e[1] == f for e in data_edges)] for u in real}
    for k, sp in spec.items():
        if k in ACT:
            desk = len([f for f in set(reads(k)) if f not in wired_reads[k]])
            tool = sp.get("tool", ""); sub = (tool + " · " if tool else "") + timing(k) + (" · GPU" if "/input/gpu" in reads(k) else "")
            nodes[k] = Node(S, k, sp["x"], sp["y"], sp["title"], sub, sp["kind"], ins[k], outs[k], exec_outs=sp.get("exec_outs", ("",)), desk=desk, dim=sp.get("dim", False))
        else: nodes[k] = Node(S, k, sp["x"], sp["y"], sp["title"], sp.get("sub", ""), sp["kind"], sp.get("ins", []), sp.get("outs", []), exec_outs=sp["exec_outs"], desk=0, dim=sp.get("dim", False))
    for n in nodes.values(): n.anchors()
    return nodes, data_edges
ALTGRP = {"route-model": ("route-relay",), "route-relay": ("route-model",), "agree": ("skip-agree",), "skip-agree": ("agree",), "use-dataset-mesh": ("pixal3d-image-to-mesh",), "pixal3d-image-to-mesh": ("use-dataset-mesh",)}

C = lambda i: 40 + i * 246
layers_all = []; scene_list = []
# ================= scene 1: the presence slice
S1 = Scene(0)
K1 = {"fetch-clips": ("Fetch motion clips", "body", "muscle-drive release"), "encode-packets": ("Encode to packets", "body", "packets-guest"), "route-model": ("Route: model", "body", "zone-router-guest"),
      "route-relay": ("Route: relay", "body", "transport-zone-relay"), "seal-and-take": ("Seal and take", "body", "observer-guest"), "judge": ("Judge", "body", "observer-guest"),
      "agree": ("Agree", "body", "replica-guest"), "skip-agree": ("Skip agreeing", "body", "pass through"), "play-curve": ("Play the curve", "body", "curve-guest"),
      "fit-anny": ("Fit the avatar", "avatar", "anny-fit-guest"), "follow": ("Avatar follows", "avatar", "anny-follow-guest"), "snapshot": ("Take a snapshot", "avatar", "presence-gates"),
      "load-omnigen2-transformer": ("Load OmniGen2", "model", "transformer"), "load-editscore-lora": ("Load EditScore", "model", "LoRA"), "merge-editscore-lora": ("Merge the LoRA", "model", "into OmniGen2"),
      "load-qwen25vl-conditioner": ("Load Qwen2.5-VL", "model", "conditioner"), "load-omnigen2-vae": ("Load the VAE", "model", "OmniGen2"), "edit": ("Edit the snapshot", "edit", "OmniGen2 + EditScore"),
      "score": ("Score the edit", "edit", "EditScore"), "check-mul-mat": ("Check mul_mat", "edit", "Lean guest")}
POS1 = {"fetch-clips": (0, 20), "encode-packets": (1, 20), "ROUTE": (2, 20), "route-model": (3, 20), "route-relay": (3, 300), "seal-and-take": (4, 20), "judge": (5, 20), "AGREE": (6, 20),
        "agree": (7, 20), "skip-agree": (7, 300), "play-curve": (8, 20), "fit-anny": (9, 20), "follow": (10, 20), "snapshot": (11, 20), "load-omnigen2-transformer": (12, 20),
        "load-editscore-lora": (13, 20), "merge-editscore-lora": (14, 20), "load-qwen25vl-conditioner": (15, 20), "load-omnigen2-vae": (16, 20), "edit": (17, 20), "score": (18, 20), "check-mul-mat": (18, 330)}
spec1 = {k: dict(x=C(POS1[k][0]), y=POS1[k][1], title=v[0], kind=v[1], tool=v[2], exec_outs=("",), dim=False) for k, v in K1.items()}
spec1["route-relay"]["dim"] = spec1["skip-agree"]["dim"] = True
spec1["ROUTE"] = dict(x=C(2), y=20, title="Route", sub="the first way that works", kind="branch", exec_outs=("model", "relay"))
spec1["AGREE"] = dict(x=C(6), y=20, title="Agree?", sub="replicas, or pass through", kind="branch", exec_outs=("replicas", "pass through"))
for k in ("ROUTE", "AGREE"): spec1[k]["x"] = C(POS1[k][0])
order1 = ["fetch-clips", "encode-packets", "ROUTE", "route-model", "route-relay", "seal-and-take", "judge", "AGREE", "agree", "skip-agree", "play-curve", "fit-anny", "follow", "snapshot",
          "load-omnigen2-transformer", "load-editscore-lora", "merge-editscore-lora", "load-qwen25vl-conditioner", "load-omnigen2-vae", "edit", "score", "check-mul-mat"]
nodes1, de1 = build_nodes(S1, spec1, order1)
ex1 = [("fetch-clips", 0, "encode-packets"), ("encode-packets", 0, "ROUTE"), ("ROUTE", 0, "route-model"), ("ROUTE", 1, "route-relay"), ("route-model", 0, "seal-and-take"), ("route-relay", 0, "seal-and-take"),
       ("seal-and-take", 0, "judge"), ("judge", 0, "AGREE"), ("AGREE", 0, "agree"), ("AGREE", 1, "skip-agree"), ("agree", 0, "play-curve"), ("skip-agree", 0, "play-curve"), ("play-curve", 0, "fit-anny"),
       ("fit-anny", 0, "follow"), ("follow", 0, "snapshot"), ("snapshot", 0, "load-omnigen2-transformer"), ("load-omnigen2-transformer", 0, "load-editscore-lora"), ("load-editscore-lora", 0, "merge-editscore-lora"),
       ("merge-editscore-lora", 0, "load-qwen25vl-conditioner"), ("load-qwen25vl-conditioner", 0, "load-omnigen2-vae"), ("load-omnigen2-vae", 0, "edit"), ("edit", 0, "score")]
CAMX[0] = C(19) + NW - (W - 80); CAMX[1] = 0
lit1, end1 = run_scene(S1, nodes1, ex1, order1, de1, "", "", [])
overlay(S1, "Part 1. From a moving body to an edited, scored image", "White wires are the sequence the planner runs. Coloured pins are facts a step reads (left) and sets (right).",
        [("The relay is transport-zone-relay: a C state machine equal to the router model, on two UDP sockets and a 64 Hz tick. Both ways to route are drawn; the planner tries the model first.", TXT),
         ("Most of this slice has not been timed. Only the loads, the edit and the score have. Every step also needs its own repository to pass its gate (not drawn).", SUB),
         ("Next, inside the relay, then the AUX route.", TXT)], end1 - 10)
S1.t1 = end1 + 60; scene_list.append(S1)

# ================= scene 2: inside the relay
S2 = Scene(S1.t1)
spec2 = {"EVENT": dict(x=C(0), y=20, title="Event Tick", sub="64 Hz: one tick is 1.5625e-2 s", kind="event", ins=[], outs=[], exec_in=False, exec_outs=("",)),
         "DRAIN": dict(x=C(1), y=20, title="Drain the sockets", sub="recvmmsg, up to 32 at a time", kind="labels", ins=[("PORT", "int"), ("PORT+1", "int")], outs=[("Datagrams", "struct")], exec_outs=("",)),
         "EACH": dict(x=C(2), y=20, title="For Each Datagram", sub="", kind="macro", ins=[("Array", "struct")], outs=[("Element", "struct")], exec_outs=("Loop Body", "Completed")),
         "WHO": dict(x=C(3), y=20, title="Who sent it?", sub="source address = person", kind="labels", ins=[("Datagram", "struct")], outs=[("Zone", "int"), ("Slot", "int"), ("Half", "int")], exec_outs=("",)),
         "PUT": dict(x=C(4), y=20, title="Offer the frame", sub="zr_put: 1 in 5 ticks, burst of two", kind="labels", ins=[("Zone", "int"), ("Slot", "int"), ("Half", "int"), ("Bytes", "struct")], outs=[("Taken", "bool")], exec_outs=("",)),
         "BR": dict(x=C(5), y=20, title="Branch", sub="", kind="branch", ins=[("Condition", "bool")], outs=[], exec_outs=("True", "False")),
         "SEND": dict(x=C(6), y=20, title="Send to the other 3", sub="sendmmsg, from the port of the same half", kind="labels", ins=[("Zone", "int"), ("Slot", "int"), ("Half", "int")], outs=[], exec_outs=("",)),
         "REFUSE": dict(x=C(6), y=250, title="Count it refused", sub="too long, a 5th person, or a half taken too soon", kind="hair", ins=[], outs=[], exec_outs=("",)),
         "TICKZ": dict(x=C(3), y=330, title="Tick every zone", sub="now + 1; a slot silent over 192 ticks is emptied", kind="motion", ins=[], outs=[], exec_outs=("",)),
         "CATCH": dict(x=C(4), y=330, title="Catch up if late", sub="one tick for each tick the wall has had", kind="motion", ins=[], outs=[], exec_outs=("",)),
         "WAIT": dict(x=C(5), y=330, title="Wait for the next tick", sub="then run the loop again", kind="motion", ins=[], outs=[], exec_outs=("",))}
nodes2 = {k: Node(S2, k, v["x"], v["y"], v["title"], v.get("sub", ""), v["kind"], v["ins"], v["outs"], exec_in=v.get("exec_in", True), exec_outs=v["exec_outs"]) for k, v in spec2.items()}
for n in nodes2.values(): n.anchors()
order2 = ["EVENT", "DRAIN", "EACH", "WHO", "PUT", "BR", "SEND", "REFUSE", "TICKZ", "CATCH", "WAIT"]
ex2 = [("EVENT", 0, "DRAIN"), ("DRAIN", 0, "EACH"), ("EACH", 0, "WHO"), ("WHO", 0, "PUT"), ("PUT", 0, "BR"), ("BR", 0, "SEND"), ("BR", 1, "REFUSE"), ("EACH", 1, "TICKZ"), ("TICKZ", 0, "CATCH"), ("CATCH", 0, "WAIT")]
de2 = [("DRAIN", "Datagrams", "EACH", "Array", False), ("EACH", "Element", "WHO", "Datagram", False), ("EACH", "Element", "PUT", "Bytes", False), ("WHO", "Zone", "PUT", "Zone", False),
       ("WHO", "Slot", "PUT", "Slot", False), ("WHO", "Half", "PUT", "Half", False), ("PUT", "Taken", "BR", "Condition", False), ("WHO", "Zone", "SEND", "Zone", False),
       ("WHO", "Slot", "SEND", "Slot", False), ("WHO", "Half", "SEND", "Half", False)]
def stats(S, nodes, lit):
    x, y = C(0), 300; S.add({"ty": 4, "nm": "comment", "ks": ks(o=S.fade(10, 24)), "shapes": [rc(x, y, 226, 232, (0.2, 0.3, 0.2), 6, (0.3, 0.45, 0.3), 1.4)]})
    for i, t in enumerate(["Measured at 256 people", "Linux, two shared vCPUs, loopback:", "median tick 1.625e-3 s, 1.655e-3 s", "99th percentile 2.43e-3 s, 2.33e-3 s", "per datagram out 4.626e-6 s,", "4.659e-6 s", "aim: a tick under 4e-3 s", "(RFD66606-2442), not a gate"]):
        text(S, x + 10, y + 22 + 24 * i, t, 12.5 if i else 14, (1, 1, 1) if i == 0 else (0.88, 0.95, 0.88), f"stat {i}", o=S.fade(14, 28))
CAMX[0] = C(7) + NW - (W - 80); CAMX[1] = 0
lit2, end2 = run_scene(S2, nodes2, ex2, order2, de2, "", "", [], extra=stats)
overlay(S2, "Part 2. Inside the relay: one loop, 64 times a second", "transport-zone-relay, in C. Strict C99, no heap, and it never reads a byte of a frame. A zone is four people.",
        [("A taken frame is copied in, handed out unchanged and sent on as it arrives, so none waits in the relay longer than one tick. A viewer gets six frames a send interval.", TXT),
         ("A frame that comes too soon is refused and counted, and its bytes are not copied. Checked against the router model's recorded trace (210 ticks); the sockets only on loopback.", SUB)], end2 - 10)
S2.t1 = S2.t0 + end2 + 70; scene_list.append(S2)

# ================= scene 3: the AUX route
S3 = Scene(S2.t1)
K3 = {"relabel-coco": ("Regroup photo labels", "labels", "COCO, 7 part types"), "make-synth-set": ("Render practice images", "labels", "Mitsuba 3"), "train-part-detector": ("Train part detector", "labels", "RF-DETR"),
      "use-dataset-mesh": ("Use dataset mesh", "labels", "GarmentCode"), "matte-image": ("Matte the image", "labels", "BiRefNet HR"), "pixal3d-image-to-mesh": ("Image to mesh", "labels", "Pixal3D on TRELLIS.2"),
      "ingest-usd": ("Load mesh", "labels", "OpenUSD"), "unitise-source": ("Scale to unit cube", "labels", "units.py"), "segment-labels": ("Label each part", "labels", "Alchemy3D-Segment"),
      "write-scale-sidecar": ("Save the scale", "labels", "units.py"), "restore-units": ("Undo the scaling", "labels", "units.py"), "close-labelling": ("Labels finished", "labels", ""),
      "build-warp": ("Build cloth simulator", "motion", "Warp"), "measure-motion-lag": ("Measure part lag", "motion", "Warp, not run yet"), "classify-soft-rigid": ("Soft or rigid?", "motion", "not built yet"),
      "make-hair-cards": ("Make hair cards", "hair", "HairDeck"), "make-spring-chains": ("Make spring chains", "hair", "HairDeck"), "rig-aux-parts": ("Rig the parts", "rig", "not built yet")}
P3 = {"relabel-coco": 0, "make-synth-set": 1, "train-part-detector": 2, "MESH": 3, "use-dataset-mesh": 4, "matte-image": 4, "pixal3d-image-to-mesh": 5, "ingest-usd": 6, "unitise-source": 7, "segment-labels": 8,
      "write-scale-sidecar": 9, "restore-units": 10, "close-labelling": 11, "build-warp": 12, "measure-motion-lag": 13, "classify-soft-rigid": 14, "make-hair-cards": 15, "make-spring-chains": 16, "rig-aux-parts": 17}
spec3 = {k: dict(x=C(P3[k]), y=20 if k != "matte-image" and k != "pixal3d-image-to-mesh" else 320, title=v[0], kind=v[1], tool=v[2], exec_outs=("",), dim=k in ("matte-image", "pixal3d-image-to-mesh")) for k, v in K3.items()}
spec3["MESH"] = dict(x=C(3), y=20, title="Where is the mesh from?", sub="the dataset, or an image", kind="branch", exec_outs=("dataset", "image"))
order3 = ["relabel-coco", "make-synth-set", "train-part-detector", "MESH", "use-dataset-mesh", "matte-image", "pixal3d-image-to-mesh", "ingest-usd", "unitise-source", "segment-labels", "write-scale-sidecar",
          "restore-units", "close-labelling", "build-warp", "measure-motion-lag", "classify-soft-rigid", "make-hair-cards", "make-spring-chains", "rig-aux-parts"]
nodes3, de3 = build_nodes(S3, spec3, order3)
chain = ["relabel-coco", "make-synth-set", "train-part-detector", "MESH"]
ex3 = [(a, 0, b) for a, b in zip(chain, chain[1:])] + [("MESH", 0, "use-dataset-mesh"), ("MESH", 1, "matte-image"), ("matte-image", 0, "pixal3d-image-to-mesh"), ("use-dataset-mesh", 0, "ingest-usd"), ("pixal3d-image-to-mesh", 0, "ingest-usd")]
tail = ["ingest-usd", "unitise-source", "segment-labels", "write-scale-sidecar", "restore-units", "close-labelling", "build-warp", "measure-motion-lag", "classify-soft-rigid", "make-hair-cards", "make-spring-chains", "rig-aux-parts"]
ex3 += [(a, 0, b) for a, b in zip(tail, tail[1:])]
CAMX[0] = C(18) - (W - 80) + NW; CAMX[1] = 0
lit3, end3 = run_scene(S3, nodes3, ex3, order3, de3, "", "", [])
overlay(S3, "Part 3. From an image or a mesh to rigged garment parts", "The planner's route for the AUX goal. The planner runs independent steps side by side; the white wire lists them one after another.",
        [("The longest chain is: build the simulator, measure which parts lag (60 min), decide soft or rigid, rig. The one GPU is a pin passed from step to step, so GPU steps take turns.", TXT),
         ("The 91 minutes leaves out image-to-mesh and matting: neither has been timed. Dim nodes are the image route, skipped when the dataset mesh is on hand.", SUB)], end3 - 10)
S3.t1 = S3.t0 + end3 + 90; scene_list.append(S3)

OP = S3.t1; idx = 0; out = []
for S in scene_list:
    cam = next(l for l in S.layers if l["ty"] == 3)
    for l in S.layers: l["op"] = S.t1
    S.layers.sort(key=lambda l: 0)  # keep drawing order: Lottie paints the first layer on top, so the list is reversed below
    out += list(reversed(S.layers))
for i, l in enumerate(out): l["ind"] = i + 1
for S in scene_list:
    cam = next(l for l in S.layers if l["ty"] == 3)
    fixed = ("background", "grid fine v", "grid fine h", "grid bold v", "grid bold h", "title strip", "caption strip")
    for l in S.layers:
        if l is cam: continue
        if l["nm"] in fixed or l["nm"] in ("title", "subtitle") or re.fullmatch(r"caption \d", l["nm"]): continue
        l["parent"] = cam["ind"]
json.dump({"v": "5.7.0", "fr": FR, "ip": 0, "op": OP, "w": W, "h": H, "nm": "poseswap plan, as Blueprints", "ddd": 0, "assets": [],
           "fonts": {"list": [{"fName": "Arial", "fFamily": "Arial", "fStyle": "Regular", "ascent": 71.6}]}, "layers": out, "markers": []}, open(sys.argv[3], "w"), separators=(",", ":"))
print("wrote", sys.argv[3], len(out), "layers,", round(OP / FR, 1), "s; scenes end at", [S.t1 for S in scene_list])
