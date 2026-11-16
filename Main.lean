import PlanLottie

open Lean PlanLottie

/-- `plan_lottie [--grid N] [--cap N] [--complexity N] [--transcript out.md] <domain.jsonld> <out.json> <plan.json>...` draws one Sequence node with a part for each plan.
Everything drawn comes from the domain and the plans. `--grid 0` puts nodes where the layout says instead of snapping them.
Exit 2: usage, 3: a file could not be read or written. -/
partial def flags (grid : Float) (cap cx : Option Nat) (transcript : Option String) : List String → Float × Option Nat × Option Nat × Option String × List String
  | "--grid" :: n :: rest => flags ((n.toNat?).map Nat.toFloat |>.getD grid) cap cx transcript rest
  | "--cap" :: n :: rest => flags grid (n.toNat?) cx transcript rest
  | "--complexity" :: n :: rest => flags grid cap (n.toNat?) transcript rest
  | "--transcript" :: p :: rest => flags grid cap cx (some p) rest
  | rest => (grid, cap, cx, transcript, rest)

def readAll : List String → IO (Except String (List Json))
  | [] => pure (.ok [])
  | f :: rest => do
    match ← readJson f with
    | .error e => pure (.error e)
    | .ok j => match ← readAll rest with
      | .error e => pure (.error e)
      | .ok js => pure (.ok (j :: js))

def main (args : List String) : IO UInt32 := do
  let (grid, cap, cx, transcript, rest) := flags 16 none none none args
  match rest with
  | domain :: out :: planFiles@(_ :: _) =>
    match ← readJson domain, ← readAll planFiles with
    | .error e, _ | _, .error e => IO.eprintln s!"cannot read: {e}" *> pure 3
    | .ok dom, .ok plans =>
      let c : Cfg := { grid, cap, maxComplexity := cx }
      match ← writeText out (render c dom plans).compress with
      | .error e => IO.eprintln s!"cannot write {e}" *> pure 3
      | .ok _ =>
        IO.println s!"wrote {out}"
        match transcript with
        | none => pure 0
        | some tp =>
          match ← writeText tp (PlanLottie.transcript c dom plans) with
          | .error e => IO.eprintln s!"cannot write {e}" *> pure 3
          | .ok _ => IO.println s!"wrote {tp}" *> pure 0
  | _ => IO.eprintln "usage: plan_lottie [--grid N] [--cap N] [--complexity N] [--transcript out.md] <domain.jsonld> <out.json> <plan.json>..." *> pure 2
