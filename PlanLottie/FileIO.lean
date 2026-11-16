import Lean.Data.Json
import YamlLd

namespace PlanLottie
open Lean

/-- A file's text, or why it could not be read: a missing file is a result, not an exception. -/
def readText (path : String) : IO (Except String String) := do
  match ← (IO.FS.readFile (System.FilePath.mk path)).toBaseIO with
  | .ok text => pure (.ok text)
  | .error e => pure (.error s!"{path}: {e}")

/-- A JSON-LD or YAML-LD document: `.yamlld` and `.yaml` are read as YAML-LD (its first document), anything else as JSON. -/
def readJson (path : String) : IO (Except String Json) := do
  match ← readText path with
  | .error e => pure (.error e)
  | .ok t =>
    if path.endsWith ".yamlld" || path.endsWith ".yaml" then
      pure (match _root_.YamlLd.parse t with | .ok j => .ok j | .error e => .error s!"{path}: not YAML-LD: {e}")
    else
      pure (match Json.parse t with | .ok j => .ok j | .error e => .error s!"{path}: not JSON: {e}")

def writeText (path text : String) : IO (Except String Unit) := do
  match ← (IO.FS.writeFile (System.FilePath.mk path) text).toBaseIO with
  | .ok _ => pure (.ok ())
  | .error e => pure (.error s!"{path}: {e}")

end PlanLottie
