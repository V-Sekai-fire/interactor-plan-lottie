import Lean.Data.Json
import PlanLottie.Lottie

/-! The poseswap plan drawn like Unreal Engine Blueprints: nodes with exec pins (the sequence) and data pins (facts a step reads and sets).
Scenes 1 and 3 are read from the domain and the planner's plan; scene 2, the relay loop, is written out by hand from transport-zone-relay's docs. -/

namespace PlanLottie
open Lean

structure Cfg where
  /-- Nodes snap to this many pixels, as Blueprint nodes do. 0 draws them where the tables say. -/
  grid : Float := 16
  /-- Hold each part on screen until its captions can be read. -/
  readPause : Bool := true
  /-- The most nodes one layer holds, or none for no limit (the default). A plan over it is drawn as a layer of Extract nodes, each opening onto a layer of its own.
  JPL's Power of Ten (rule 4) would give 30, the bound for a compound statement. -/
  cap : Option Nat := none
  /-- The most independent paths through one layer (its Branch nodes plus one), or none for no limit (the default). NASA's SWE-220 allows 15 for safety-critical code and reads 10 or less as well structured. -/
  maxComplexity : Option Nat := none
def Cfg.snap (c : Cfg) (v : Float) : Float := if c.grid > 0 then Float.round (v / c.grid) * c.grid else v
def Cfg.nw (c : Cfg) : Float := if c.grid > 0 then 208 else 210
def Cfg.pitch (c : Cfg) : Float := if c.grid > 0 then 256 else 246
def Cfg.col (c : Cfg) (i : Nat) : Float := c.snap 40 + i.toFloat * c.pitch

def W : Float := 1680
def H : Float := 720
def c3 (r g b : Float) : Col := ⟨r, g, b⟩
def BGC := c3 0.085 0.085 0.095
def GRID1 := c3 0.115 0.115 0.125
def GRID2 := c3 0.15 0.15 0.165
def BODY := c3 0.155 0.155 0.168
def EDGE := c3 0.04 0.04 0.045
def TXT := c3 0.86 0.86 0.88
def SUB := c3 0.62 0.62 0.66
def WHITE := c3 0.97 0.97 0.97
def STRIP := c3 0.05 0.05 0.057

def hdr : String → Col
  | "labels" | "body" => c3 0.12 0.33 0.62
  | "motion" | "model" => c3 0.66 0.38 0.08
  | "hair" => c3 0.13 0.46 0.27
  | "rig" | "edit" => c3 0.42 0.24 0.62
  | "avatar" => c3 0.1 0.46 0.44
  | "event" => c3 0.62 0.1 0.1
  | "extract" => c3 0.12 0.42 0.52
  | "branch" => c3 0.32 0.32 0.36
  | _ => c3 0.3 0.3 0.34

def pinCol : String → Col
  | "body" => c3 0.1 0.8 0.66
  | "avatar" => c3 0.36 0.66 1.0
  | "image" => c3 1.0 0.46 0.76
  | "model" => c3 1.0 0.8 0.22
  | "aux" => c3 0.46 0.9 0.4
  | "course" => c3 0.98 0.58 0.22
  | "gpu" => c3 0.9 0.2 0.2
  | "op" => c3 0.8 0.6 1.0
  | "struct" => c3 0.0 0.46 0.95
  | "int" => c3 0.1 0.8 0.66
  | "bool" => c3 0.85 0.15 0.15
  | _ => c3 0.6 0.6 0.66

/-! ## What the domain says -/

def entries (j : Json) : List (String × Json) :=
  match j.getObj? with
  | .ok o => o.toList
  | .error _ => []
def items (j : Json) : List Json := match j.getArr? with | .ok a => a.toList | .error _ => []
def strOf (j : Json) : String := match j.getStr? with | .ok s => s | .error _ => ""

structure Act where
  reads : List String
  sets : List String
  duration : Option String
  basis : String

def actsOf (dom : Json) : List (String × Act) :=
  (entries (dom.getObjValD "actions")).map fun (k, a) =>
    let body := items (a.getObjValD "body")
    (k, { reads := body.filterMap fun b => match b.getObjVal? "eval" with | .ok e => some (strOf (e.getObjValD "pointer")) | .error _ => none
        , sets := body.filterMap fun b => match b.getObjVal? "pointer/set" with | .ok p => some (strOf p) | .error _ => none
        , duration := match (a.getObjValD "duration").getStr? with | .ok s => some s | .error _ => none
        , basis := strOf (a.getObjValD "duration_basis") })

/-- Seconds of an ISO 8601 duration such as PT1H2M3S, or none when it is not one. -/
def secs (iso : String) : Option Nat :=
  match iso.toList with
  | 'P' :: 'T' :: rest =>
    let r := rest.foldl (fun (acc : Nat × Nat × Bool) c =>
      let (tot, cur, ok) := acc
      if c.isDigit then (tot, cur * 10 + (c.toNat - '0'.toNat), ok)
      else if c == 'H' then (tot + cur * 3600, 0, ok)
      else if c == 'M' then (tot + cur * 60, 0, ok)
      else if c == 'S' then (tot + cur, 0, ok)
      else (tot, cur, false)) (0, 0, true)
    if r.2.2 then some r.1 else none
  | _ => none

def span (s : Nat) : String :=
  if s < 60 then s!"{s} s" else s!"{s / 60} min" ++ (if s % 60 != 0 then s!" {s % 60} s" else "")

def timing (acts : List (String × Act)) (a : String) : String :=
  match acts.lookup a with
  | none => "not timed"
  | some act => match act.duration.bind secs with
    | none => "not timed"
    | some d => span d ++ (if act.basis.startsWith "estimate" then " est." else "")

def pinType (f : String) : String := if f == "/input/gpu" then "gpu" else ((f.splitOn "/").getD 1 "input")
def pinLabel (f : String) : String := if f == "/input/gpu" then "GPU" else ((f.splitOn "/").getLast?).getD f

/-! ## Nodes -/

structure Node where
  key : String
  title : String
  sub : String
  kind : String
  x : Float
  y : Float
  ins : List (String × String) := []
  outs : List (String × String) := []
  execIn : Bool := true
  execOuts : List String := [""]
  desk : Nat := 0
  dim : Bool := false

def Node.head (n : Node) : Float := 28 + (if n.sub.isEmpty then 0 else 14)
def Node.rows (n : Node) : Nat := max n.ins.length n.outs.length + (if n.desk > 0 then 1 else 0)
def Node.rawH (n : Node) : Float := n.head + 8 + (max n.execOuts.length 1).toFloat * 20 + n.rows.toFloat * 20 + 8
def Node.h (c : Cfg) (n : Node) : Float := if c.grid > 0 then Float.ceil (n.rawH / c.grid) * c.grid else n.rawH
def Node.y0 (n : Node) : Float := n.y + n.head + 8 + (max n.execOuts.length 1).toFloat * 20
def Node.execInPos (n : Node) : Float × Float := (n.x + 12, n.y + n.head + 18)
def Node.execOutPos (c : Cfg) (n : Node) (i : Nat) : Float × Float := (n.x + c.nw - 12, n.y + n.head + 18 + 20 * i.toFloat)
def Node.pinIn (n : Node) (k : String) : Float × Float := (n.x + 12, n.y0 + 10 + ((n.ins.findIdx? (·.1 == k)).getD 0).toFloat * 20)
def Node.pinOut (c : Cfg) (n : Node) (k : String) : Float × Float := (n.x + c.nw - 12, n.y0 + 10 + ((n.outs.findIdx? (·.1 == k)).getD 0).toFloat * 20)

/-- The layers of one node. `lit` is the frame it runs at, none for a node that is shown but not run. -/
def Node.draw (c : Cfg) (t0 : Float) (n : Node) (wiredIn wiredOut : List String) (lit : Option Float) (execInWired : Bool) (execOutWired : List Bool) : List Json :=
  let a : Float := if n.dim then 0.55 else 1
  let nw := c.nw; let h := n.h c; let color := hdr n.kind
  let items : List Json :=
    [rc n.x n.y nw h (some BODY) 7 (some (EDGE, 1.4)), rc n.x n.y nw n.head (some color) 7, rc n.x (n.y + n.head - 8) nw 8 (some color) 0]
    ++ (if n.execIn then [execpin n.execInPos.1 n.execInPos.2 WHITE execInWired] else [])
    ++ (n.execOuts.zip (List.range n.execOuts.length)).map (fun (_, i) =>
         let p := n.execOutPos c i; execpin p.1 p.2 WHITE ((execOutWired.getD i false)))
    ++ n.ins.map (fun (k, t) => let p := n.pinIn k; circle p.1 p.2 4.5 (pinCol t) (wiredIn.contains k))
    ++ n.outs.map (fun (k, t) => let p := n.pinOut c k; circle p.1 p.2 4.5 (pinCol t) (wiredOut.contains k))
  let body := layer t0 [("ty", PlanLottie.n 4), ("nm", str s!"node {n.key}"), ("ks", ks (0, 0) (some (lin t0 [(8, [0]), (22, [100 * a])]))), ("shapes", A items.reverse)]
  let flash := match lit with
    | none => []
    | some t => [layer t0 [("ty", PlanLottie.n 4), ("nm", str s!"flash {n.key}"), ("ks", ks (0, 0) (some (lin t0 [(t, [0]), (t + 5, [100]), (t + 30, [0])]))),
                  ("shapes", A [rc n.x n.y nw n.head (some ⟨1, 1, 1⟩) 7 none 18, rc n.x n.y nw h none 7 (some (WHITE, 2.6))])]]
  let fo := some (fade t0 12 26)
  let texts : List Json :=
    [text t0 (n.x + 10) (n.y + 19) n.title 14 ⟨1, 1, 1⟩ s!"ntitle {n.key}" 0 fo]
    ++ (if n.sub.isEmpty then [] else [text t0 (n.x + 10) (n.y + 34) n.sub 11.5 ⟨0.9, 0.9, 0.92⟩ s!"nsub {n.key}" 0 fo])
    ++ ((n.execOuts.zip (List.range n.execOuts.length)).filterMap fun (nm, i) =>
         if nm.isEmpty then none else some (text t0 (n.x + nw - 24) (n.y + n.head + 22 + 20 * i.toFloat) nm 12 TXT s!"exec {n.key} {i}" 1 fo))
    ++ n.ins.map (fun (k, _) => let p := n.pinIn k; text t0 (p.1 + 12) (p.2 + 4) (pinLabel k) 12 TXT s!"in {n.key} {k}" 0 fo)
    ++ n.outs.map (fun (k, _) => let p := n.pinOut c k; text t0 (p.1 - 12) (p.2 + 4) (pinLabel k) 12 TXT s!"out {n.key} {k}" 1 fo)
    ++ (if n.desk > 0 then [text t0 (n.x + 12) (n.y + h - 10) s!"+ {n.desk} stated by the desk" 11 SUB s!"desk {n.key}" 0 fo] else [])
  [body] ++ flash ++ texts

/-! ## Scenes -/

abbrev DataEdge := String × String × String × String × Bool
abbrev ExecEdge := String × Nat × String

def gridLayers (t0 : Float) : List Json :=
  let bg := layer t0 [("ty", PlanLottie.n 4), ("nm", str "background"), ("ks", ks), ("shapes", A [rc 0 0 W H (some BGC) 0])]
  let lines := [(20.0, GRID1, 1.0, "grid fine"), (100.0, GRID2, 1.5, "grid bold")].flatMap fun (step, color, wd, nm) =>
    [("v", true), ("h", false)].map fun (ax, vertical) =>
      let count := (if vertical then W else H) / step + 1
      let rect := J [("ty", str "rc"), ("d", PlanLottie.n 1), ("s", still (if vertical then fl [wd, H] else fl [W, wd])), ("p", still (if vertical then fl [0, H / 2] else fl [W / 2, 0])), ("r", still (PlanLottie.n 0))]
      let rp := J [("ty", str "rp"), ("c", still (PlanLottie.n (Float.floor count))), ("o", still (PlanLottie.n 0)), ("m", PlanLottie.n 0),
                   ("tr", J [("ty", str "tr"), ("p", still (if vertical then fl [step, 0] else fl [0, step])), ("a", still (fl [0, 0])), ("s", still (fl [100, 100])), ("r", still (PlanLottie.n 0)), ("so", still (PlanLottie.n 100)), ("eo", still (PlanLottie.n 100))])]
      layer t0 [("ty", PlanLottie.n 4), ("nm", str s!"{nm} {ax}"), ("ks", ks), ("shapes", A [J [("ty", str "gr"), ("nm", str nm), ("it", A [rect, fill color, rp, TR])]])]
  bg :: lines

/-- Reading time in frames at 30 a second: a pause to take the screen in, then about 13 characters a second. -/
def readFrames (lines : List String) : Float := 60 + 2.3 * (lines.foldl (fun (acc : Nat) (l : String) => acc + l.length) 0).toFloat

/-- A caption shows from `a` and, when `b` is given, is gone at `b`. -/
def window (t0 a : Float) (b : Option Float) : Json :=
  let k : List (Float × List Float) := [(a, [(0 : Float)]), (a + 14, [(100 : Float)])] ++ (match b with | some e => [(e - 14, [(100 : Float)]), (e, [(0 : Float)])] | none => [])
  lin t0 k

structure Caption where
  lines : List (String × Col)
  start : Float
  stop : Option Float

def overlay (t0 : Float) (title sub : String) (caps : List Caption) : List Json :=
  let first := ((caps.head?).map (·.start)).getD 0
  [layer t0 [("ty", PlanLottie.n 4), ("nm", str "title strip"), ("ks", ks), ("shapes", A [rc 0 0 W 112 (some STRIP) 0])],
   text t0 40 52 title 30 ⟨1, 1, 1⟩ "title" 0 (some (fade t0 0 14)), text t0 40 82 sub 15 SUB "subtitle" 0 (some (fade t0 6 20)),
   layer t0 [("ty", PlanLottie.n 4), ("nm", str "caption strip"), ("ks", ks (0, 0) (some (fade t0 first (first + 12)))), ("shapes", A [rc 0 (H - 100) W 100 (some STRIP) 0])]]
  ++ (caps.flatMap fun cap => (cap.lines.zip (List.range cap.lines.length)).map fun ((t, color), i) =>
       text t0 40 (H - 70 + 26 * i.toFloat) t 15 color s!"caption {i}" 0 (some (window t0 (cap.start + 4 * i.toFloat) cap.stop)))

structure SceneOut where
  layers : List Json
  endFrame : Float
  lits : List (String × Float)

/-- Draw one graph: comments, then wires under the nodes, then the nodes, then a camera that follows the node that runs.
`gapAfter` names the steps after which the run pauses, so the camera has time to travel to the next part. -/
def runScene (c : Cfg) (t0 : Float) (nodes : List Node) (execEdges : List ExecEdge) (order : List String) (dataEdges : List DataEdge)
    (camMaxX camMaxY : Float) (under : List Json) (padAfter : List (String × Float)) : SceneOut :=
  let step : Float := 24; let T0 : Float := 36
  let pad := fun (k : String) => (padAfter.lookup k).getD 0
  let lit := fun (k : String) => (order.findIdx? (· == k)).map fun i =>
    T0 + i.toFloat * step + ((order.take i).foldl (fun acc q => acc + pad q) 0)
  let node := fun (k : String) => nodes.find? (·.key == k)
  let dataWires := dataEdges.filterMap fun (s, f, d, g, dash) =>
    match node s, node d, lit s with
    | some ns, some nd, some ls =>
      let t := (ns.outs.lookup f).getD "int"
      some (wire t0 (ns.pinOut c f) (nd.pinIn g) (pinCol t) 2.4 (ls + 6) (ls + 26) s!"data {s} {f} {d}" dash)
    | _, _, _ => none
  let execWires := execEdges.filterMap fun (s, i, d) =>
    match node s, node d with
    | some ns, some nd =>
      let ld := (lit d).getD T0
      some (wire t0 (ns.execOutPos c i) nd.execInPos WHITE 3.2 (ld - 16) (ld - 2) s!"exec {s} {d}")
    | _, _ => none
  let drawn := nodes.flatMap fun nd =>
    let wIn := dataEdges.filterMap fun (_, _, d, g, _) => if d == nd.key then some g else none
    let wOut := dataEdges.filterMap fun (s, f, _, _, _) => if s == nd.key then some f else none
    let eIn := execEdges.any fun (_, _, d) => d == nd.key
    let eOut := (List.range nd.execOuts.length).map fun i => execEdges.any fun (s, j, _) => s == nd.key && j == i
    nd.draw c t0 wIn wOut (if nd.dim then none else lit nd.key) eIn eOut
  let cam := order.filterMap fun k => match node k, lit k with
    | some nd, some l =>
      let tx := min (max (nd.x + c.nw / 2 - 760) 0) camMaxX
      let ty := min (max (nd.y + nd.h c / 2 - 270) 0) camMaxY
      some (l - 10, [40 - tx, 150 - ty, 0])
    | _, _ => none
  let cam := match cam.head? with | some (_, p) => (0, p) :: cam | none => cam
  let camLayer := layer t0 [("ty", PlanLottie.n 3), ("nm", str "camera"),
    ("ks", J [("o", still (PlanLottie.n 100)), ("r", still (PlanLottie.n 0)), ("p", lin t0 cam true), ("a", still (fl [0, 0, 0])), ("s", still (fl [100, 100, 100]))])]
  let lastKey := (order.getLast?).getD ""
  let lastLit := (lit lastKey).getD T0
  { layers := gridLayers t0 ++ under ++ dataWires ++ execWires ++ drawn ++ [camLayer], endFrame := lastLit + pad lastKey + 40,
    lits := order.filterMap fun k => (lit k).map fun l => (k, l) }

/-- A Blueprint comment box: a tinted rectangle around some nodes, with a title above it. -/
def comment (t0 x y w h : Float) (color : Col) (title : String) : List Json :=
  [layer t0 [("ty", PlanLottie.n 4), ("nm", str s!"comment {title}"), ("ks", ks (0, 0) (some (fade t0 8 22))),
             ("shapes", A [rc x y w h (some color) 8 (some (⟨color.r + 0.12, color.g + 0.12, color.b + 0.12⟩, 1.6)) 22])],
   text t0 (x + 14) (y + 26) title 17 ⟨0.95, 0.95, 0.97⟩ s!"commenttitle {title}" 0 (some (fade t0 10 24))]

/-! ## Building the nodes of a domain scene -/

structure Spec where
  key : String
  title : String
  kind : String
  col : Nat
  y : Float
  tool : String := ""
  sub : String := ""
  execOuts : List String := [""]
  dim : Bool := false
  execIn : Bool := true
  ins : List (String × String) := []
  outs : List (String × String) := []

def dedup (xs : List String) : List String := xs.foldl (fun acc x => if acc.contains x then acc else acc ++ [x]) []

/-- Nodes and data wires from the domain: a pin is a fact a step reads or sets, a wire joins the last earlier step that sets a fact
to the step that reads it (and the alternatives to that step, each a solid wire from its own branch). Facts nothing sets are counted as stated by the desk. -/
def buildNodes (c : Cfg) (acts : List (String × Act)) (alts : String → List String) (specs : List Spec) (orderAll : List String) : List Node × List DataEdge :=
  let real := orderAll.filter fun k => (acts.lookup k).isSome
  let setsOf := fun k => ((acts.lookup k).map (·.sets)).getD []
  let readsOf := fun k => ((acts.lookup k).map (·.reads)).getD []
  let edges : List DataEdge := (real.zip (List.range real.length)).flatMap fun (v, i) =>
    (readsOf v).flatMap fun f =>
      let prior := (real.take i).filter fun u => (setsOf u).contains f
      match prior.getLast? with
      | none => []
      | some last =>
        let group := prior.filter fun u => (alts last).contains u
        (dedup (group ++ [last])).map fun u => (u, f, v, f, false)
  let wiredReads := fun v => dedup (edges.filterMap fun (_, f, d, _, _) => if d == v then some f else none)
  let nodes := specs.map fun sp =>
    match acts.lookup sp.key with
    | some act =>
      let wr := wiredReads sp.key
      let ins := wr.map fun f => (f, pinType f)
      let outs := (act.sets.filter fun f => edges.any fun (s, g, _, _, _) => s == sp.key && g == f).map fun f => (f, pinType f)
      let desk := (dedup act.reads).filter (fun f => !wr.contains f) |>.length
      let sub := (if sp.tool.isEmpty then "" else sp.tool ++ " · ") ++ timing acts sp.key ++ (if act.reads.contains "/input/gpu" then " · GPU" else "")
      { key := sp.key, title := sp.title, sub, kind := sp.kind, x := c.col sp.col, y := c.snap sp.y, ins, outs, execOuts := sp.execOuts, desk, dim := sp.dim }
    | none => { key := sp.key, title := sp.title, sub := sp.sub, kind := sp.kind, x := c.col sp.col, y := c.snap sp.y, ins := sp.ins, outs := sp.outs, execIn := sp.execIn, execOuts := sp.execOuts, dim := sp.dim }
  (nodes, edges)

def chain : List String → List ExecEdge
  | a :: b :: rest => (a, 0, b) :: chain (b :: rest)
  | _ => []

end PlanLottie
