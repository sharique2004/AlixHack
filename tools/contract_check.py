"""Strict CONTRACT-SETTLEMENT.md conformance check over every sample case,
run through the compiled settlement-api binary. Exit 0 = 0 violations."""
import json, subprocess, sys
BIN='./.lake/build/bin/settlement-api'
d=json.load(open('demo/content/settlement_samples.json'))
CLS={"probate","non_probate","unknown"}
BASIS={"jtwros_survivorship","community_property_ros","beneficiary_designation","pod_tod","trust_funded","sole_name_no_designation","beneficiary_predeceased_falls_to_estate","designation_to_estate","unknown_title"}
RS={"qualifies","does_not_qualify","needs_information"}; VD={"ELIGIBLE","INCOMPLETE_INFO","OTHER_FORM_REQUIRED"}
FS={"required","not_required","needs_information","payable","not_payable"}; SEV={"critical","warning","info"}; DS={"computed","awaiting_event","needs_information"}
FLAGIDS=set("slayer_rule_screen wrongful_death_vs_survival_claim simultaneous_death_120h insurance_contestability_window pending_death_certificate insolvent_estate medicaid_estate_recovery minor_beneficiary special_needs_beneficiary ancillary_probate_required will_copy_only conflict_risk business_continuity workers_comp_death_benefit va_benefits".split())
ROUTES=set("ca_direct_transfer ca_personal_property_affidavit ca_small_value_real_property_affidavit ca_primary_residence_petition ca_spousal_property_petition ca_formal_probate_or_other fl_disposition_without_administration fl_summary_administration fl_formal_administration".split())
FALLBACK={"ca_formal_probate_or_other","fl_formal_administration"}
errs=[]; chk=lambda c,m: None if c else errs.append(m); n=0
for s in d['samples']:
    sid=s['id']; p=subprocess.run([BIN],input=json.dumps(s['case']),capture_output=True,text=True); n+=1
    chk(p.returncode==0, f"{sid}: exit {p.returncode}"); r=json.loads(p.stdout)
    if 'error' in r:
        chk(set(r)=={'error'} and r['error']['code'] in {"invalid_date","after_snapshot","malformed_case"} and r['error']['detail'], f"{sid}: bad envelope"); continue
    chk(set(r)=={'engine','snapshot','asset_map','probate_estate','jurisdictions','federal','flags','deadlines','next_actions','unresolved_facts','notes'}, f"{sid}: top keys")
    allmissing=[]
    for a in r['asset_map']:
        chk(set(a)=={'name','classification','basis','reason','citation','missing_facts','counts_toward','value_cents'}, f"{sid}: asset keys")
        chk(a['classification'] in CLS and (a['basis'] is None or a['basis'] in BASIS) and bool(a['reason']), f"{sid}/{a['name']}: enum/reason")
        chk(a['classification']=='unknown' or a['citation'] is not None, f"{sid}/{a['name']}: conclusion without citation")
        chk((a['classification']=='unknown')==(len(a['missing_facts'])>0), f"{sid}/{a['name']}: unknown iff missing_facts")
        chk(a['value_cents'] is None or (isinstance(a['value_cents'],int) and a['value_cents']>=0), f"{sid}: value not integer cents")
        allmissing+=a['missing_facts']
        for ct in a['counts_toward']: chk(ct in ROUTES, f"{sid}: counts_toward {ct}")
    pe=r['probate_estate']
    chk(pe['status'] in {"known","partial"} and (pe['status']=='partial')==(len(pe['missing_facts'])>0) and isinstance(pe['known_subtotal_cents'],int), f"{sid}: probate_estate")
    for j in r['jurisdictions']:
        chk(j['role'] in {"domicile","ancillary"} and j['verdict'] in VD, f"{sid}: jurisdiction header")
        needs=any(x['status']=='needs_information' for x in j['routes'])
        qual=any(x['status']=='qualifies' and x['route'] not in FALLBACK for x in j['routes'])
        want='INCOMPLETE_INFO' if needs else ('ELIGIBLE' if qual else 'OTHER_FORM_REQUIRED')
        if j['routes']: chk(j['verdict']==want, f"{sid}/{j['code']}: verdict {j['verdict']} != {want}")
        for rr in j['routes']:
            chk(set(rr)=={'route','label','status','reasons','missing_facts','forms','citations'}, f"{sid}: route keys")
            chk(rr['route'] in ROUTES and rr['status'] in RS, f"{sid}: route id/status")
            chk((rr['status']=='needs_information')==(len(rr['missing_facts'])>0), f"{sid}/{rr['route']}: needs_info iff missing_facts")
            chk((rr['status']=='does_not_qualify')==(len(rr['reasons'])>0), f"{sid}/{rr['route']}: reasons iff ruled out")
            chk(len(rr['citations'])>0, f"{sid}/{rr['route']}: route without citation")
    fedmiss=[]
    for f in r['federal']:
        chk(f['item'] in {"irs_form_1310","ssa_lump_sum_death_payment"} and f['status'] in FS and len(f['citations'])>0, f"{sid}: federal row")
        chk((f['status']=='needs_information')==(len(f['missing_facts'])>0), f"{sid}: fed needs_info iff missing_facts")
        if f['item']=='irs_form_1310':
            chk(f['status'] in {"required","not_required","needs_information"} and f['payee'] is None and f['amount_cents'] is None, f"{sid}: 1310 out of range")
        else:
            chk(f['status'] in {"payable","not_payable","needs_information"} and f['payee']!='estate', f"{sid}: lump sum out of range")
        fedmiss+=f['missing_facts']
    chk([x['item'] for x in r['federal']]==["irs_form_1310","ssa_lump_sum_death_payment"], f"{sid}: federal order")
    for fl in r['flags']:
        chk(fl['id'] in FLAGIDS and fl['severity'] in SEV and fl['citation'] is not None, f"{sid}: flag {fl['id']}")
    for dl in r['deadlines']:
        chk(dl['status'] in DS and (dl['status']=='computed')==(dl['date'] is not None) and dl['citation'] is not None, f"{sid}: deadline {dl['id']}")
    union=[]
    for x in allmissing+pe['missing_facts']+[m for j in r['jurisdictions'] for rr in j['routes'] for m in rr['missing_facts']]+fedmiss:
        if x not in union: union.append(x)
    chk(set(union)<=set(r['unresolved_facts']), f"{sid}: unresolved_facts misses {set(union)-set(r['unresolved_facts'])}")
    chk(len(r['unresolved_facts'])==len(set(r['unresolved_facts'])), f"{sid}: duplicate unresolved facts")
print(f"{n} samples checked against CONTRACT-SETTLEMENT.md §§0,3,4,5")
if errs: print("FAILURES:"); [print(' -',e) for e in errs]; sys.exit(1)
print("contract shape: OK — 0 violations")
