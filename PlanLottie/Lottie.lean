import Lean.Data.Json

/-! The pieces of a Lottie document: numbers, keyframes, shapes, text and layers, as `Lean.Json` values. -/

namespace PlanLottie
open Lean

abbrev F := Float
structure Col where
  r : Float
  g : Float
  b : Float

def n (x : Float) : Json := toJson x
def J (kvs : List (String × Json)) : Json := Json.mkObj kvs
def A (xs : List Json) : Json := Json.arr xs.toArray
def fl (xs : List Float) : Json := A (xs.map n)
def str (s : String) : Json := Json.str s
def still (v : Json) : Json := J [("a", n 0), ("k", v)]
def col (c : Col) : Json := fl [c.r, c.g, c.b, 1]

/-- Keyframes at `t0 + t`; `ease` uses the soft curve the camera moves on, else linear. -/
def lin (t0 : Float) (ts : List (Float × List Float)) (ease : Bool := false) : Json :=
  let cnt := ((ts.head?).map (·.2.length)).getD 1
  let rep := fun (x : Float) => A ((List.replicate cnt x).map n)
  let (ox, oy, ix, iy) := if ease then ((0.33 : Float), (0 : Float), (0.67 : Float), (1 : Float)) else (0, 0, 1, 1)
  let body := ts.dropLast.map fun (t, v) =>
    J [("t", n (t + t0)), ("s", fl v), ("i", J [("x", rep ix), ("y", rep iy)]), ("o", J [("x", rep ox), ("y", rep oy)])]
  let tail := match ts.getLast? with
    | some (t, v) => [J [("t", n (t + t0)), ("s", fl v)]]
    | none => []
  J [("a", n 1), ("k", A (body ++ tail))]

def fade (t0 f0 f1 : Float) : Json := lin t0 [(f0, [0]), (f1, [100])]

def ks (p : Float × Float := (0, 0)) (o : Option Json := none) : Json :=
  J [("o", o.getD (still (n 100))), ("r", still (n 0)), ("p", still (fl [p.1, p.2, 0])), ("a", still (fl [0, 0, 0])), ("s", still (fl [100, 100, 100]))]

def TR : Json := J [("ty", str "tr"), ("p", still (fl [0, 0])), ("a", still (fl [0, 0])), ("s", still (fl [100, 100])), ("r", still (n 0)), ("o", still (n 100))]
def grp (items : List Json) (nm : String := "g") : Json := J [("ty", str "gr"), ("nm", str nm), ("it", A (items ++ [TR]))]

def fill (c : Col) (opacity : Float := 100) : Json := J [("ty", str "fl"), ("c", still (col c)), ("o", still (n opacity)), ("r", n 1)]
def stroke (c : Col) (w : Float) (dash : Bool := false) : Json :=
  J ([("ty", str "st"), ("c", still (col c)), ("o", still (n 100)), ("w", still (n w)), ("lc", n 2), ("lj", n 2)]
    ++ (if dash then [("d", A [J [("n", str "d"), ("nm", str "dash"), ("v", still (n 8))], J [("n", str "g"), ("nm", str "gap"), ("v", still (n 6))]])] else []))

def rc (x y w h : Float) (f : Option Col) (r : Float := 6) (s : Option (Col × Float) := none) (opacity : Float := 100) : Json :=
  grp ([J [("ty", str "rc"), ("d", n 1), ("s", still (fl [w, h])), ("p", still (fl [x + w / 2, y + h / 2])), ("r", still (n r))]]
    ++ (f.map (fill · opacity)).toList ++ (s.map fun (c, sw) => stroke c sw).toList) "rect"

def circle (x y r : Float) (c : Col) (filled : Bool) : Json :=
  grp ([J [("ty", str "el"), ("s", still (fl [2 * r, 2 * r])), ("p", still (fl [x, y]))], stroke c 1.8] ++ (if filled then [fill c] else [])) "pin"

def execpin (x y : Float) (white : Col) (filled : Bool) : Json :=
  let pts := [[x - 5, y - 6], [x + 2, y - 6], [x + 7, y], [x + 2, y + 6], [x - 5, y + 6]]
  let zero := (List.replicate 5 [(0 : Float), 0]).map fl
  grp ([J [("ty", str "sh"), ("ks", still (J [("c", Json.bool true), ("v", A (pts.map fl)), ("i", A zero), ("o", A zero)]))], stroke white 1.8]
    ++ (if filled then [fill white] else [])) "exec"

def bez (p1 p2 : Float × Float) : Json :=
  let d := max 50 (Float.abs (p2.1 - p1.1) * 0.5)
  J [("c", Json.bool false), ("v", A [fl [p1.1, p1.2], fl [p2.1, p2.2]]), ("i", A [fl [0, 0], fl [-d, 0]]), ("o", A [fl [d, 0], fl [0, 0]])]

/-- A layer: the fields a Lottie layer needs, with the index and the out point filled in later. -/
def layer (t0 : Float) (fields : List (String × Json)) : Json :=
  J (fields ++ [("ddd", n 0), ("ind", n 0), ("sr", n 1), ("ao", n 0), ("ip", n t0), ("op", n 0), ("st", n 0), ("bm", n 0)])

def wire (t0 : Float) (p1 p2 : Float × Float) (c : Col) (width ta tb : Float) (name : String) (dash : Bool := false) : Json :=
  let tm := J [("ty", str "tm"), ("s", still (n 0)), ("e", lin t0 [(ta, [0]), (tb, [100])]), ("o", still (n 0)), ("m", n 1)]
  let st := stroke c width dash
  layer t0 [("ty", n 4), ("nm", str name), ("ks", ks), ("shapes", A [grp [J [("ty", str "sh"), ("ks", still (bez p1 p2)), ("nm", str "path")], tm, st] name])]

def text (t0 : Float) (x y : Float) (t : String) (size : Float) (c : Col) (name : String) (j : Float := 0) (o : Option Json := none) : Json :=
  let d := J [("s", n size), ("f", str "Arial"), ("t", str t), ("j", n j), ("tr", n 0), ("lh", n (size * 1.25)), ("ls", n 0), ("fc", fl [c.r, c.g, c.b])]
  layer t0 [("ty", n 5), ("nm", str name), ("ks", ks (x, y) o),
            ("t", J [("d", J [("k", A [J [("s", d), ("t", n 0)]])]), ("p", J []), ("m", J [("g", n 1), ("a", still (fl [0, 0]))]), ("a", A [])])]

/-- Set one field of a JSON object; anything that is not an object comes back unchanged. -/
def setKey (j : Json) (k : String) (v : Json) : Json :=
  match j.getObj? with
  | .ok o => Json.obj (o.insert k v)
  | .error _ => j

end PlanLottie
