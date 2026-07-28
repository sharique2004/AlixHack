import SimpleProbate.Api

/-!
Entry point for the `probate-api` executable: read one `CaseInput` JSON
document on stdin, write one `CheckResult` JSON document on stdout, exit 0.
Case errors AND unparseable input both produce an error-result JSON with
exit 0; only an internal panic exits nonzero.
-/

def main : IO Unit := do
  let stdin ← IO.getStdin
  let input ← stdin.readToEnd
  IO.println (SimpleProbate.Api.run input).compress
