import SimpleProbate.Router.Assess

/-!
# JSON encoding

`SettlementAssessment` → the contract's response body, and `RouterError` → the
contract's error envelope. Every enum string comes from a `wireName` in
`SimpleProbate.Router.Report`; no field name and no enum value is spelled twice
in this repository.

`run` is the whole pipeline: raw stdin text in, one JSON document out.
Unparseable input, an unknown enum value and a post-snapshot death date all
leave through the error envelope. Nothing throws.
-/

namespace SimpleProbate
namespace Router
namespace Encode

open Lean (Json)

private def natJson (n : Nat) : Json := Json.num ⟨Int.ofNat n, 0⟩

private def optNatJson : Option Nat → Json
  | some n => natJson n
  | none => Json.null

private def optStrJson : Option String → Json
  | some s => Json.str s
  | none => Json.null

private def strArr (xs : List String) : Json := Json.arr (xs.map Json.str).toArray

def dateJson (d : CivilDate) : Json :=
  Json.mkObj [("year", natJson d.year), ("month", natJson d.month), ("day", natJson d.day)]

private def optDateJson : Option CivilDate → Json
  | some d => dateJson d
  | none => Json.null

def citationJson (c : Citation) : Json :=
  Json.mkObj [("label", Json.str c.label), ("url", optStrJson c.url)]

private def optCitationJson : Option Citation → Json
  | some c => citationJson c
  | none => Json.null

private def citationsJson (cs : List Citation) : Json :=
  Json.arr (cs.map citationJson).toArray

def reasonJson (r : Reason) : Json :=
  Json.mkObj [("id", Json.str r.id), ("text", Json.str r.text)]

private def reasonsJson (rs : List Reason) : Json :=
  Json.arr (rs.map reasonJson).toArray

def assetClassificationJson (a : AssetClassification) : Json :=
  Json.mkObj [
    ("name", Json.str a.name),
    ("classification", Json.str a.classification.wireName),
    ("basis", match a.basis with
      | some b => Json.str b.wireName
      | none => Json.null),
    ("reason", Json.str a.reason),
    ("citation", optCitationJson a.citation),
    ("missing_facts", strArr a.missingFacts),
    ("counts_toward", strArr a.countsToward),
    ("value_cents", optNatJson a.valueCents)
  ]

def probateEstateJson (e : ProbateEstate) : Json :=
  Json.mkObj [
    ("known_subtotal_cents", natJson e.knownSubtotalCents),
    ("status", Json.str e.status.wireName),
    ("missing_facts", strArr e.missingFacts)
  ]

def routeRowJson (r : RouteRow) : Json :=
  Json.mkObj [
    ("route", Json.str r.route),
    ("label", Json.str r.label),
    ("status", Json.str r.status.wireName),
    ("reasons", reasonsJson r.reasons),
    ("missing_facts", strArr r.missingFacts),
    ("forms", strArr r.forms),
    ("citations", citationsJson r.citations)
  ]

def jurisdictionJson (j : JurisdictionReport) : Json :=
  Json.mkObj [
    ("code", Json.str j.code),
    ("role", Json.str j.role.wireName),
    ("verdict", Json.str j.verdict.wireName),
    ("routes", Json.arr (j.routes.map routeRowJson).toArray)
  ]

def federalJson (f : FederalReport) : Json :=
  Json.mkObj [
    ("item", Json.str f.item),
    ("label", Json.str f.label),
    ("status", Json.str f.status.wireName),
    ("payee", optStrJson f.payee),
    ("amount_cents", optNatJson f.amountCents),
    ("reasons", reasonsJson f.reasons),
    ("missing_facts", strArr f.missingFacts),
    ("citations", citationsJson f.citations)
  ]

def flagJson (f : Flag) : Json :=
  Json.mkObj [
    ("id", Json.str f.id),
    ("severity", Json.str f.severity.wireName),
    ("title", Json.str f.title),
    ("detail", Json.str f.detail),
    ("citation", optCitationJson f.citation),
    ("triggered_by", strArr f.triggeredBy),
    ("action", Json.str f.action)
  ]

def deadlineJson (d : Deadline) : Json :=
  Json.mkObj [
    ("id", Json.str d.id),
    ("label", Json.str d.label),
    ("status", Json.str d.status.wireName),
    ("date", optDateJson d.date),
    ("relative_to", Json.str d.relativeTo),
    ("offset_days", optNatJson d.offsetDays),
    ("citation", optCitationJson d.citation)
  ]

def nextActionJson (a : NextAction) : Json :=
  Json.mkObj [
    ("id", Json.str a.id),
    ("label", Json.str a.label),
    ("blocked_by", strArr a.blockedBy)
  ]

def assessmentJson (a : SettlementAssessment) : Json :=
  Json.mkObj [
    ("engine", Json.str a.engine),
    ("snapshot", Json.mkObj [
      ("source_as_of", Json.str a.snapshot.sourceAsOf),
      ("supported_death_dates_through", Json.str a.snapshot.supportedDeathDatesThrough)
    ]),
    ("asset_map", Json.arr (a.assetMap.map assetClassificationJson).toArray),
    ("probate_estate", probateEstateJson a.probateEstate),
    ("jurisdictions", Json.arr (a.jurisdictions.map jurisdictionJson).toArray),
    ("federal", Json.arr (a.federal.map federalJson).toArray),
    ("flags", Json.arr (a.flags.map flagJson).toArray),
    ("deadlines", Json.arr (a.deadlines.map deadlineJson).toArray),
    ("next_actions", Json.arr (a.nextActions.map nextActionJson).toArray),
    ("unresolved_facts", strArr a.unresolvedFacts),
    ("notes", strArr a.notes)
  ]

instance : Lean.ToJson SettlementAssessment := ⟨assessmentJson⟩

def errorJson (e : RouterError) : Json :=
  Json.mkObj [
    ("error", Json.mkObj [("code", Json.str e.code), ("detail", Json.str e.detail)])
  ]

def resultJson : Except RouterError SettlementAssessment → Json
  | .ok assessment => assessmentJson assessment
  | .error e => errorJson e

/-- Raw stdin text → one response document. -/
def run (input : String) : Json :=
  match Json.parse input with
  | .error parseError =>
    errorJson ⟨"malformed_case", s!"Input was not valid JSON: {parseError}"⟩
  | .ok j =>
    match decodeIntakeCase j with
    | .error decodeError => errorJson ⟨"malformed_case", decodeError⟩
    | .ok intake => resultJson (assess intake)

end Encode
end Router
end SimpleProbate
