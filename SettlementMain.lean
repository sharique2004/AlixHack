import SimpleProbate.Router.Encode
import SimpleProbate.Router.Tests

/-!
# settlement-api entry point

Stdin JSON (`IntakeCase`) → stdout JSON (`SettlementAssessment` | error envelope),
per `CONTRACT-SETTLEMENT.md`. Exit code is always 0; failures are reported inside
the JSON envelope, never as a crash — same discipline as `probate-api`.

`SimpleProbate.Router.Tests` is imported for its effect on the build: the
regression examples in it are `by decide` proofs, so they are checked every
time this executable is compiled. A broken classification rule fails the build
rather than shipping.
-/

def main : IO Unit := do
  let stdin ← IO.getStdin
  let input ← stdin.readToEnd
  IO.println (SimpleProbate.Router.Encode.run input).compress
