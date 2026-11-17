import PlanLottie

/-! Checks for the plan-to-Lottie converter. Each check is run on the real output and, where it can fail, on a planted fault that it must catch.
The converter may hide what the JSON-LD says but may not add to it: the leak checks render from planted domains and require that
every drawn word either carries a mark put on every string of the JSON-LD, or is one of a short list of words of the drawing language itself.
usage: plan_lottie_witness <domain.yamlld> <golden transcript.md> <plan.yamlld>... -/

open Lean PlanLottie

structure Check where
  name : String
  ok : Bool

partial def walk (j : Json) : List Json :=
  j :: (match j with
        | .arr a => a.toList.flatMap walk
        | .obj o => o.toList.flatMap fun (_, v) => walk v
        | _ => [])

def layersOf (doc : Json) : List Json := items (doc.getObjValD "layers")
def isProperty (c : Json) : Bool := (c.getObjVal? "k").toOption.isSome

def coloursOk (doc : Json) : Bool :=
  (walk doc).all fun x =>
    match x.getObjVal? "ty" with
    | .ok t => if t == str "fl" || t == str "st" then isProperty (x.getObjValD "c") else true
    | .error _ => true

/-- A dotted line is not a thing in a Blueprint: an alternative is a Branch node, and every wire is solid. -/
def noDashes (doc : Json) : Bool := (walk doc).all fun x => (x.getObjVal? "d").toOption.isNone || (x.getObjValD "ty") != str "st"

def uniqueInds (doc : Json) : Bool :=
  let inds := (layersOf doc).map fun l => (l.getObjValD "ind").compress
  inds.length == (inds.foldl (fun (acc : List String) x => if acc.contains x then acc else acc ++ [x]) []).length

def cameraInd (doc : Json) : Option String :=
  (layersOf doc).findSome? fun l => if strOf (l.getObjValD "nm") == "camera" then some (l.getObjValD "ind").compress else none

def parentsOk (doc : Json) : Bool :=
  match cameraInd doc with
  | none => false
  | some ci => (layersOf doc).all fun l => match l.getObjVal? "parent" with | .ok p => p.compress == ci | .error _ => true

def nodeNames (doc : Json) : List String :=
  (layersOf doc).filterMap fun l =>
    let nm := strOf (l.getObjValD "nm")
    if nm.startsWith "node " then some (String.ofList (nm.toList.drop 5)) else none

def wiresOk (m : Model) : Bool :=
  m.dataEdges.all fun (s, f, d, g, _) =>
    match m.nodes.find? (·.key == s), m.nodes.find? (·.key == d) with
    | some ns, some nd => (ns.outs.lookup f).isSome && (nd.ins.lookup g).isSome
    | _, _ => false

partial def reach (exec : List ExecEdge) (seen : List String) (frontier : List String) : List String :=
  match frontier with
  | [] => seen
  | k :: rest =>
    let next := (exec.filterMap fun (s, _, d) => if s == k && !seen.contains d then some d else none)
    reach exec (seen ++ next) (rest ++ next)

def unreached (m : Model) (exec : List ExecEdge) : List String :=
  let seen := reach exec ["RUN"] ["RUN"]
  (m.nodes.map (·.key)).filter fun k => !seen.contains k

def onGrid (g : Float) (v : Float) : Bool := g > 0 && Float.round (v / g) * g == v
def snapped (c : Cfg) (m : Model) : Bool := m.nodes.all fun n => onGrid c.grid n.x && onGrid c.grid n.y && onGrid c.grid (n.h c)
def subsFit (m : Model) : Bool := m.nodes.all fun n => n.sub.length ≤ 34
def readable (c : Cfg) (dom : Json) (plans : List Json) : Bool := (readingWindows c dom plans).all fun (need, avail) => avail ≥ need


/-- The steps the layers hold. -/
def heldSteps (m : Model) : List String := m.parts.flatMap (·.steps)

/-- The most independent paths through any one layer. -/

def opOf (doc : Json) : Float := match doc.getObjVal? "op" with | .ok o => ((o.getNum?).toOption.map (·.toFloat)).getD 0 | .error _ => 0

/-! ## Leaks: nothing drawn that the JSON-LD did not say -/

def mark (s : String) : String := if s == "goal" then s else "§ ".intercalate (s.splitOn " ") ++ "§"

def textsOf (doc : Json) : List String :=
  (walk doc).filterMap fun x => match x.getObjVal? "t" with
    | .ok t => (match (((t.getObjValD "d").getObjValD "k")) with
        | .arr a => (a.toList.head?).bind fun k => (((k.getObjValD "s").getObjValD "t").getStr?).toOption
        | _ => none)
    | .error _ => none

partial def markAll : Json → Json
  | .str s => .str (mark s)
  | .arr a => .arr (a.map markAll)
  | .obj o => Json.mkObj (o.toList.map fun (k, v) => (k, markAll v))
  | j => j

/-- Mark every string the converter reads: the domain's name and description, the variables' descriptions, the actions' and methods' keys and strings, the plans' steps. -/
def markDomain (dom : Json) : Json :=
  let acts := Json.mkObj ((entries (dom.getObjValD "actions")).map fun (k, a) => (mark k, markAll a))
  let meths := Json.mkObj ((entries (dom.getObjValD "methods")).map fun (k, m) => (mark k, markAll m))
  let vars := A ((items (dom.getObjValD "variables")).map fun v => setKey v "description" (str (mark (strOf (v.getObjValD "description")))))
  setKey (setKey (setKey (setKey (setKey dom "actions" acts) "methods" meths) "variables" vars) "name" (str (mark (strOf (dom.getObjValD "name"))))) "description" (str (mark (strOf (dom.getObjValD "description"))))

def markPlan (p : Json) : Json :=
  setKey p "steps" (A ((items (p.getObjValD "steps")).map fun s => setKey s "action" (str (mark (strOf (s.getObjValD "action"))))))

/-- The words of the drawing language: the Sequence node, its outputs, a missing time, a GPU pin. -/
def chrome (s : String) : Bool :=
  s == "Sequence" || s == "not timed" || s == "not timed · GPU" || s == "GPU" || s == "" ||
  ((s.startsWith "Then ") && (s.drop 5).toString.all Char.isDigit) ||
  ((s.startsWith "Then ") && !((s.drop 5).toString.takeWhile Char.isDigit).isEmpty && ((s.drop 5).toString.dropWhile Char.isDigit).toString == ". ") ||
  ((s.startsWith "+ ") && (s.endsWith " stated by the desk") && !((s.drop 2).toString.takeWhile Char.isDigit).isEmpty)

def unmarked (c : Cfg) (dom : Json) (plans : List Json) : List String :=
  (textsOf (render c (markDomain dom) (plans.map markPlan))).filter fun t => !(t.any (· == '§')) && !chrome t

def main (args : List String) : IO UInt32 := do
  match args with
  | domainP :: goldenP :: planPs@(_ :: _) =>
    let mut plans : List Json := []
    for f in planPs do
      match ← readJson f with
      | .ok j => plans := plans ++ [j]
      | .error e => IO.eprintln s!"cannot read: {e}"; return 3
    match ← readJson domainP, ← readText goldenP with
    | .ok dom, .ok golden =>
      let c : Cfg := {}
      let doc := render c dom plans
      let m := model c dom plans
      let noPause := render { c with readPause := false } dom plans
      let badColour := J [("ty", str "fl"), ("c", fl [0, 0, 0, 1])]
      let goodColour := J [("ty", str "fl"), ("c", still (fl [0, 0, 0, 1]))]
      let dup := match layersOf doc with
        | a :: b :: rest => A (a :: setKey b "ind" (a.getObjValD "ind") :: rest)
        | _ => A []
      let longSub : Node := { key := "x", title := "x", sub := "a line that runs out past the right edge of its node", kind := "body", x := 0, y := 0 }
      let allSteps := plans.flatMap plannedOf
      let groups := groupsOf dom
      let altPrims := groups.flatMap fun g => g.alts.flatMap (·.prims)
      let invented := (nodeNames doc).filter fun k => !allSteps.contains k && !altPrims.contains k && !k.startsWith "BR " && !k.startsWith "EX " && k != "RUN" && k != "SEQ"
      let planMinus := plans.map fun p => setKey p "steps" (A ((items (p.getObjValD "steps")).filter fun s => strOf (s.getObjValD "action") != (allSteps.headD "")))
      let hidden := (nodeNames (render c dom planMinus)).contains (allSteps.headD "")
      let emptyDom := J [("actions", J []), ("methods", J []), ("variables", A [])]
      let emptyPlan := J [("steps", A [])]
      let leakTexts := (textsOf (render c emptyDom [emptyPlan, emptyPlan])).filter (!chrome ·)
      let planted := textsOf (render c (setKey dom "name" (str "plain")) plans)
      let described := (allSteps.filter fun k => ((actsOf dom).lookup k).any (·.description != "")).headD ""
      let descLine := ((wrapLines (((actsOf dom).lookup described).map (·.description) |>.getD "") 44 3).headD "")
      let undescribed := setKey dom "actions" (Json.mkObj ((entries (dom.getObjValD "actions")).map fun (k, a) => (k, if k == described then setKey a "description" (str "") else a)))
      let oneStep := (plans.take 1).map fun p => setKey p "steps" (A ((items (p.getObjValD "steps")).take 1))
      let checks : List Check :=
        [ { name := "GOLDEN every step of every plan is a node", ok := allSteps.all (nodeNames doc).contains },
          { name := "CONTROL a step taken out of the plans is no longer drawn", ok := !hidden || allSteps.headD "" == "" },
          { name := "GOLDEN every drawn node is a plan step, an alternative of a method, a Branch, or the two head nodes", ok := invented.isEmpty },
          { name := "GOLDEN every data wire joins a pin that exists", ok := wiresOk m },
          { name := "CONTROL a wire to a pin that does not exist is refused", ok := !wiresOk { m with dataEdges := (allSteps.headD "", "nope", allSteps.headD "", "nope", false) :: m.dataEdges } },
          { name := "GOLDEN the sequence reaches every node from the event", ok := (unreached m m.exec).isEmpty },
          { name := "CONTROL a missing exec wire leaves nodes unreached", ok := !(unreached m (m.exec.drop 3)).isEmpty },
          { name := "INVARIANT every step is held by exactly one layer, in order", ok := heldSteps m == allSteps },
          { name := "CONTROL a layer taken out loses its steps", ok := heldSteps { m with parts := m.parts.drop 2 } != allSteps },
          { name := "INVARIANT every node, and its height, sits on the 16-pixel grid", ok := snapped c m },
          { name := "CONTROL with the grid off, some node is off the grid", ok := !(snapped c (model { c with grid := 0 } dom plans)) },
          { name := "INVARIANT every sub-line fits inside a node (34 characters)", ok := subsFit m },
          { name := "CONTROL a sub-line that is too long is caught", ok := !subsFit { m with nodes := longSub :: m.nodes } },
          { name := "INVARIANT each part stays on screen as long as its caption takes to read", ok := readable c dom plans },
          { name := "CONTROL without the reading pauses a part of one node is on screen too short a time for its caption", ok := !readable { c with readPause := false } dom oneStep },
          { name := "CONTROL with the reading pauses that same part of one node is held long enough", ok := readable c dom oneStep },
          { name := "INVARIANT shape colours are animatable properties", ok := coloursOk doc },
          { name := "CONTROL a bare-array colour is caught", ok := coloursOk goodColour && !coloursOk badColour },
          { name := "INVARIANT no wire is dotted: alternatives are Branch nodes", ok := noDashes doc },
          { name := "CONTROL a dashed stroke is caught", ok := !noDashes (J [("ty", str "st"), ("d", A [J [("n", str "d")]])]) },
          { name := "INVARIANT every layer has its own index", ok := uniqueInds doc },
          { name := "CONTROL two layers with one index are caught", ok := !uniqueInds (J [("layers", dup)]) },
          { name := "INVARIANT every parent is the camera", ok := parentsOk doc },
          { name := "GOLDEN the transcript equals the committed one", ok := PlanLottie.transcript c dom plans == golden },
          { name := "CONTROL a changed transcript is not equal to the golden", ok := PlanLottie.transcript c dom plans ++ "x" != golden },
          { name := "INVARIANT the animation is longer with the reading pauses than without", ok := opOf doc > opOf noPause },
          { name := "LEAK from an empty domain and empty plans only the words of the drawing language are drawn", ok := leakTexts.isEmpty },
          { name := "LEAK with every string of the JSON-LD marked, every drawn word carries the mark", ok := (unmarked c dom plans).isEmpty },
          { name := "CONTROL a word the JSON-LD did not give is caught as unmarked", ok := !((["Fetch the clips"].filter fun t => !(t.any (· == '§')) && !chrome t).isEmpty) },
          { name := "CONTROL a changed domain name reaches the drawing", ok := planted != textsOf doc },
          { name := "GOLDEN a time keeps its milliseconds: PT0.056S is 56 ms, PT3.202S is 3.202 s, PT21.45S is 21.45 s, PT1M7S is 1 min 7 s, PT30S is 30 s, PT0S is 0 s",
            ok := (millis "PT0.056S").map span == some "56 ms" && (millis "PT3.202S").map span == some "3.202 s" && (millis "PT21.45S").map span == some "21.45 s"
              && (millis "PT1M7S").map span == some "1 min 7 s" && (millis "PT30S").map span == some "30 s" && (millis "PT0S").map span == some "0 s" },
          { name := "CONTROL a time that is not ISO 8601 with at most three decimals is not timed: PT0.5555S, 1.5 and a word",
            ok := (millis "PT0.5555S").isNone && (millis "1.5").isNone && (millis "soon").isNone },
          { name := "GOLDEN an action's description is drawn under its node, wrapped to the node's width",
            ok := !described.isEmpty && !descLine.isEmpty && (textsOf doc).any (· == descLine) },
          { name := "CONTROL with the description taken out of the domain, that line is no longer drawn",
            ok := !((textsOf (render c undescribed plans)).any (· == descLine)) } ]
      for ch in checks do IO.println s!"  [{if ch.ok then "ok  " else "FAIL"}] {ch.name}"
      let bad := checks.filter (!·.ok)
      if bad.isEmpty then
        IO.println s!"OK: plan_lottie, {checks.length} checks hold"
        pure 0
      else
        for t in (unmarked c dom plans).take 12 do IO.println s!"    unmarked: {t}"
        for t in leakTexts.take 12 do IO.println s!"    from nothing: {t}"
        IO.println s!"FAIL: {bad.length} of {checks.length} checks failed"
        pure 1
    | _, _ => IO.eprintln "cannot read an input" *> pure 3
  | _ => IO.eprintln "usage: plan_lottie_witness <domain.yamlld> <golden transcript.md> <plan.yamlld>..." *> pure 2
