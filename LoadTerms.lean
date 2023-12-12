import Lean
open Lean

structure TestS where
  name : String

open Lean Elab Command

def runCommandElabM (env : Environment) (x : CommandElabM α) : IO α := do
  let cmdCtx := {
    fileName     := "<empty>"
    fileMap      := .ofString ""
    tacticCache? := none
  }
  match (← liftM <| EIO.toIO' <| (x cmdCtx).run { env, maxRecDepth := maxRecDepth.defValue }) with
  | .ok (a, _) => return a
  | .error e =>
    throw <| IO.Error.userError s!"unexpected internal error: {← e.toMessageData.toString}"

unsafe def readTermFromFileName (fileName : String) : IO TestS := do
  let code ← IO.FS.readFile ⟨fileName⟩
  initSearchPath (← Lean.findSysroot) ["build/lib"]
  -- this should be the name of the current module, or the one that contains the `TestS` definition
  let env ← importModules #[`LoadTerms] {}
  runCommandElabM env <| runTermElabM fun _ => do
    let .ok stx := Lean.Parser.runParserCategory env `term code | throwError "parse error"
    let ty := .const ``TestS []
    let e ← Term.elabTerm stx (some ty)
    Meta.evalExpr TestS ty e

unsafe def main (args : List String) : IO Unit := do
  let fileName := args.head!
  let s : TestS ← readTermFromFileName fileName
  IO.println s!"Hello, {s.name}"
