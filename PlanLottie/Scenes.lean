import PlanLottie.Graph

/-! The poseswap plan as one Blueprint graph. Everything drawn comes from the planner's domain and plans:
a node is a plan step (its title is the action's key, its pins are the facts it reads and sets, its time is its duration),
a Branch node is a composite method with two or more alternatives, and a caption is a variable's description.
Nothing here names a step, a tool or a number of its own. A Sequence node runs one part for each plan. -/

namespace PlanLottie
open Lean

def humanize (k : String) : String :=
  let w := k.replace "-" " "
  match w.toList with
  | c :: cs => String.ofList (c.toUpper :: cs)
  | [] => w

def lastSeg (p : String) : String := ((p.splitOn "/").getLast?).getD p

/-- Words wrapped to lines of about `width` characters; text past `maxLines` is hidden behind an ellipsis. -/
def wrapLines (text : String) (width maxLines : Nat) : List String :=
  let words := (text.splitOn " ").filter (· != "")
  let lines := words.foldl (fun (acc : List String) w =>
    match acc.getLast? with
    | some l => if l.length + 1 + w.length ≤ width then acc.dropLast ++ [l ++ " " ++ w] else acc ++ [w]
    | none => [w]) []
  if lines.length ≤ maxLines then lines
  else lines.take (maxLines - 1) ++ [(lines.getD (maxLines - 1) "") ++ " …"]

/-! ## The domain's alternatives -/

structure Alt where
  name : String
  prims : List String

structure Group where
  goal : String
  alts : List Alt

/-- Each composite method with two or more alternatives; an alternative's primitive steps are the actions its subtasks name. -/
def groupsOf (dom : Json) : List Group :=
  let known := fun (k : String) => ((dom.getObjValD "actions").getObjVal? k).toOption.isSome
  (entries (dom.getObjValD "methods")).filterMap fun (g, m) =>
    let alts := (items (m.getObjValD "alternatives")).map fun a =>
      ({ name := strOf (a.getObjValD "name"),
         prims := (items (a.getObjValD "subtasks")).filterMap fun t =>
           match items t with
           | [x] => (match x.getStr? with | .ok k => if known k then some k else none | .error _ => none)
           | _ => none } : Alt)
    if alts.length ≥ 2 then some { goal := g, alts } else none

def altsOf (groups : List Group) (u : String) : List String :=
  groups.flatMap fun g =>
    if g.alts.any (·.prims.contains u) then (g.alts.filter fun a => !a.prims.contains u).flatMap (·.prims) else []

def plannedOf (plan : Json) : List String := dedup ((items (plan.getObjValD "steps")).map fun s => strOf (s.getObjValD "action"))

/-! ## Laying a plan out -/

inductive Item where
  | single (k : String)
  | branch (g : Group) (taken : Nat)

def takenAlt (g : Group) (steps : List String) : Option Nat :=
  (g.alts.zip (List.range g.alts.length)).findSome? fun (a, i) => if !a.prims.isEmpty && a.prims.all steps.contains then some i else none

def primsOf (g : Group) (t : Nat) : List String := ((g.alts[t]?).map (·.prims)).getD []

def itemsOf (groups : List Group) (steps : List String) : List Item :=
  let rel := groups.filterMap fun g => (takenAlt g steps).map fun t => (g, t)
  (steps.foldl (fun (acc : List Item × List String) k =>
    match rel.find? fun (g, t) => (primsOf g t).contains k with
    | some (g, t) => if acc.2.contains g.goal then acc else (acc.1 ++ [Item.branch g t], acc.2 ++ [g.goal])
    | none => (acc.1 ++ [Item.single k], acc.2)) ([], [])).1

structure Laid where
  specs : List Spec := []
  order : List String := []
  exec : List ExecEdge := []
  first : String := ""

structure LayState where
  laid : Laid := {}
  col : Nat := 2
  prevs : List (String × Nat)

def branchKey (g : Group) : String := "BR " ++ g.goal

def kindOfVar : String → String
  | "body" => "body" | "avatar" => "avatar" | "image" => "edit" | "model" => "model" | "op" => "edit"
  | "aux" => "labels" | "course" => "motion" | "relay" => "hair" | _ => "body"

def layPart (kindOf : String → String) (partNo : Nat) (row : Float) (steps : List String) (groups : List Group) : Laid :=
  let init : LayState := { prevs := [("SEQ", partNo)] }
  let done := (itemsOf groups steps).foldl (fun (st : LayState) it =>
    let l := st.laid
    match it with
    | .single k =>
      { laid := { specs := l.specs ++ [{ key := k, title := humanize k, kind := kindOf k, col := st.col, y := row }], order := l.order ++ [k],
                  exec := l.exec ++ st.prevs.map (fun (p, i) => (p, i, k)), first := if l.first == "" then k else l.first },
        col := st.col + 1, prevs := [(k, 0)] }
    | .branch g t =>
      let bk := branchKey g
      let idx := g.alts.zip (List.range g.alts.length)
      let altSpecs := idx.flatMap fun (a, i) => (a.prims.zip (List.range a.prims.length)).map fun (k, j) =>
        ({ key := k, title := humanize k, kind := kindOf k, col := st.col + 1 + j, y := row + 300 * i.toFloat, dim := i != t } : Spec)
      let bspec : Spec := { key := bk, title := humanize (lastSeg g.goal) ++ "?", kind := "branch", col := st.col, y := row, execOuts := g.alts.map (·.name) }
      let altExec := idx.flatMap fun (a, i) => match a.prims.head? with | some h => (bk, i, h) :: chain a.prims | none => []
      let maxLen := g.alts.foldl (fun m a => max m a.prims.length) 1
      { laid := { specs := l.specs ++ [bspec] ++ altSpecs, order := l.order ++ [bk] ++ g.alts.flatMap (·.prims),
                  exec := l.exec ++ st.prevs.map (fun (p, i) => (p, i, bk)) ++ altExec, first := if l.first == "" then bk else l.first },
        col := st.col + 1 + maxLen, prevs := g.alts.filterMap fun a => a.prims.getLast?.map (·, 0) }) init
  done.laid

/-! ## Captions: a variable's own description -/

def dominantVar (acts : List (String × Act)) (steps : List String) : Option String :=
  let vars := (steps.flatMap fun k => ((acts.lookup k).map (·.sets)).getD []).map pinType
  (dedup vars).foldl (fun (best : Option (String × Nat)) v =>
    let n := (vars.filter (· == v)).length
    match best with
    | some (_, m) => if n > m then some (v, n) else best
    | none => some (v, n)) none |>.map (·.1)

def captionOf (dom : Json) (acts : List (String × Act)) (steps : List String) : List String :=
  match dominantVar acts steps with
  | none => []
  | some v => match (items (dom.getObjValD "variables")).find? fun x => strOf (x.getObjValD "name") == v with
    | some x => wrapLines (strOf (x.getObjValD "description")) 118 3
    | none => []

/-! ## The model -/

structure PartInfo where
  steps : List String
  laid : Laid
  row : Float
  caption : List String

structure Model where
  nodes : List Node
  dataEdges : List DataEdge
  exec : List ExecEdge
  order : List String
  parts : List PartInfo
  maxCol : Nat

def rowOf (i : Nat) : Float := 20 + 600 * i.toFloat

def model (c : Cfg) (dom : Json) (plans : List Json) : Model :=
  let acts := actsOf dom
  let groups := groupsOf dom
  let kindOf := fun (k : String) => match (acts.lookup k).bind (·.sets.head?) with | some p => kindOfVar (pinType p) | none => "body"
  let parts := (plans.zip (List.range plans.length)).map fun (p, i) =>
    let steps := plannedOf p
    ({ steps, laid := layPart kindOf i (rowOf i) steps groups, row := rowOf i, caption := captionOf dom acts steps } : PartInfo)
  let head : List Spec :=
    [{ key := "RUN", title := strOf (dom.getObjValD "name"), kind := "event", col := 0, y := rowOf 0, execIn := false },
     { key := "SEQ", title := "Sequence", kind := "branch", col := 1, y := rowOf 0, execOuts := (List.range plans.length).map fun i => s!"Then {i}" }]
  let specs := head ++ parts.flatMap (·.laid.specs)
  let orderAll := parts.flatMap (·.laid.order)
  let (nodes, dataEdges) := buildNodes c acts (altsOf groups) specs orderAll
  { nodes, dataEdges, exec := [("RUN", 0, "SEQ")] ++ parts.flatMap (·.laid.exec), order := ["RUN", "SEQ"] ++ orderAll, parts,
    maxCol := specs.foldl (fun m sp => max m sp.col) 2 }

def fixedNames : List String := ["background", "grid fine v", "grid fine h", "grid bold v", "grid bold h", "title strip", "caption strip", "title", "subtitle"]

structure Built where
  m : Model
  sc : SceneOut
  starts : List Float
  titles : List String

def partTitle (m : Model) (i : Nat) (p : PartInfo) : String :=
  let t := fun (k : String) => ((m.nodes.find? (·.key == k)).map (·.title)).getD k
  let lastK := (p.laid.order.getLast?).getD p.laid.first
  s!"Then {i}. " ++ t p.laid.first ++ (if lastK == p.laid.first then "" else " to " ++ t lastK)

def partColors : List Col := [c3 0.2 0.35 0.6, c3 0.2 0.5 0.3, c3 0.45 0.25 0.6, c3 0.6 0.35 0.15]

def build (c : Cfg) (dom : Json) (plans : List Json) : Built :=
  let m := model c dom plans
  let t0 : Float := 0
  let x1 := c.col 2 - 24
  let idx := m.parts.zip (List.range m.parts.length)
  let titles := idx.map fun (p, i) => partTitle m i p
  let under := (idx.zip titles).flatMap fun ((p, i), title) =>
    comment t0 x1 (c.snap p.row - 64) (c.col m.maxCol + c.nw + 24 - x1) 536 (partColors.getD (i % 4) (c3 0.3 0.3 0.3)) title
  let step : Float := 24
  let pad := fun (cap : List String) (nodesInPart : Nat) => max 60 (readFrames cap - nodesInPart.toFloat * step)
  let pads := if c.readPause then ("SEQ", (90 : Float)) :: (m.parts.filterMap fun p => (p.laid.order.getLast?).map fun k => (k, pad p.caption p.laid.order.length)) else []
  let lastRow := (m.parts.getLast?).map (·.row) |>.getD (rowOf 0)
  let sc := runScene c t0 m.nodes m.exec m.order m.dataEdges (c.col m.maxCol + c.nw - (W - 80) + 40) (lastRow + 340) under pads
  let lit := fun (k : String) => (sc.lits.lookup k).getD 0
  { m, sc, titles, starts := m.parts.map fun p => lit ((p.laid.order.head?).getD "") - 10 }

/-- For each part: the frames its caption needs to be read, and the frames it stays on screen. -/
def readingWindows (c : Cfg) (dom : Json) (plans : List Json) : List (Float × Float) :=
  let b := build c dom plans
  (b.m.parts.zip (List.range b.m.parts.length)).map fun (p, i) =>
    let s := b.starts.getD i 0
    let e := (b.starts[i+1]?).getD b.sc.endFrame
    (readFrames p.caption, e - s)

def render (c : Cfg) (dom : Json) (plans : List Json) : Json :=
  let b := build c dom plans
  let t0 : Float := 0
  let name := strOf (dom.getObjValD "name")
  let idx := b.m.parts.zip (List.range b.m.parts.length)
  let caps : List Caption := idx.map fun (p, i) => { lines := p.caption.map (·, TXT), start := b.starts.getD i 0, stop := b.starts[i+1]? }
  let overlays := overlay t0 name ((wrapLines (strOf (dom.getObjValD "description")) 150 1).headD "") caps
  let op := b.sc.endFrame + 60
  let all := (b.sc.layers ++ overlays).reverse
  let camIdx := ((all.findIdx? fun l => strOf (l.getObjValD "nm") == "camera")).getD 0
  let finished := (all.zip (List.range all.length)).map fun (l, i) =>
    let l := setKey (setKey l "ind" (PlanLottie.n (i + 1).toFloat)) "op" (PlanLottie.n op)
    let nm := strOf (l.getObjValD "nm")
    if i == camIdx || fixedNames.contains nm || nm.startsWith "caption " then l else setKey l "parent" (PlanLottie.n (camIdx + 1).toFloat)
  J [("v", str "5.7.0"), ("fr", PlanLottie.n 30), ("ip", PlanLottie.n 0), ("op", PlanLottie.n op), ("w", PlanLottie.n W), ("h", PlanLottie.n H), ("nm", str name),
     ("ddd", PlanLottie.n 0), ("assets", A []), ("fonts", J [("list", A [J [("fName", str "Arial"), ("fFamily", str "Arial"), ("fStyle", str "Regular"), ("ascent", PlanLottie.n 71.6)]])]),
     ("layers", A finished),
     ("markers", A ((idx.zip b.titles).map fun ((_, i), name) => J [("tm", PlanLottie.n (b.starts.getD i 0)), ("cm", str name), ("dr", PlanLottie.n 0)]))]

/-- The same graph as text, in reading order: a text alternative for the animation. -/
def transcript (c : Cfg) (dom : Json) (plans : List Json) : String :=
  let b := build c dom plans
  let m := b.m
  let title := fun (k : String) => ((m.nodes.find? (·.key == k)).map (·.title)).getD k
  let stop := fun (t : String) => if t.endsWith "." || t.endsWith "?" || t.endsWith "!" then t else t ++ "."
  let line := fun (i : Nat) (k : String) =>
    match m.nodes.find? (·.key == k) with
    | none => ""
    | some nd =>
      let act := (actsOf dom).lookup k
      let wired := dedup (m.dataEdges.filterMap fun (_, _, d, g, _) => if d == k then some g else none)
      let reads := wired.map fun g => s!"{pinLabel g} from " ++ " or ".intercalate (dedup (m.dataEdges.filterMap fun (s, _, d, g', _) => if d == k && g' == g then some (title s) else none))
      let sets := match act with | some a => dedup (a.sets.map pinLabel) | none => []
      let outs := nd.execOuts.filter (· != "")
      s!"{i + 1}. " ++ stop nd.title ++ (if nd.sub.isEmpty then "" else " " ++ stop nd.sub)
        ++ (if reads.isEmpty then "" else " Reads " ++ ", ".intercalate reads ++ ".")
        ++ (if sets.isEmpty then "" else " Sets " ++ ", ".intercalate sets ++ ".")
        ++ (if outs.isEmpty then "" else " Then goes to: " ++ ", ".intercalate outs ++ ".")
        ++ (if nd.dim then " Not taken in this plan." else "")
  "# " ++ strOf (dom.getObjValD "name") ++ "\n\n"
    ++ "".intercalate ((m.parts.zip (List.range m.parts.length)).map fun (p, i) =>
         s!"## {partTitle m i p}\n\n" ++ "\n".intercalate p.caption ++ "\n\n" ++ "\n".intercalate ((p.laid.order.zip (List.range p.laid.order.length)).map fun (k, j) => line j k) ++ "\n\n")

end PlanLottie
