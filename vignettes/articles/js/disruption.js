const R25 = D.rates.find(r => r.cohort === "2025"), R23 = D.rates.find(r => r.cohort !== "2025");
const C25 = D.counts.find(r => r.cohort === "2025"), C23 = D.counts.find(r => r.cohort !== "2025");
const dol = Object.fromEntries(D.dollars.map(r => [r.category, r]));
const dis = ["terminated (formal)", "terminated (quiet truncation)", "reduced", "stalled"];
const sum = (k, cats) => cats.reduce((s, c) => s + (dol[c] ? dol[c][k] : 0), 0);
const term = ["terminated (formal)", "terminated (quiet truncation)"];
const excessTerm = C25.terminated - C25.active * R23.terminated / 100;
const orgsDis = D.org_exposure.reduce((s, r) => s + r.orgs_any_disrupted, 0);
const orgsAct = D.org_exposure.reduce((s, r) => s + r.orgs_active, 0);
const orgsTerm = null;

document.getElementById("m-end").textContent = D.meta.data_end;
document.querySelectorAll(".m-end2").forEach(e => e.textContent = D.meta.data_end);
document.getElementById("m-win").textContent = D.meta.window_days;
document.getElementById("m-orgs").textContent = fmt.n(D.meta.n_crosswalk_ein) + " nonprofits (EINs) in the crosswalk";
document.getElementById("n25").textContent = fmt.n(C25.active);
document.getElementById("n23").textContent = fmt.n(C23.active);

const tiles = [
  [fmt.n(C25.active), "active grants and contracts on 20 Jan 2025", fmt.n(orgsAct) + " organizations"],
  [fmt.n(C25.terminated), "terminated in the window (formal or quiet)", fmt.x(R25.terminated / R23.terminated) + " the 2023 rate · ≈" + fmt.n(excessTerm) + " above baseline"],
  [fmt.n(C25.terminated_formal), "formally terminated", fmt.x(R25.terminated_formal / R23.terminated_formal) + " the 2023 rate"],
  [fmt.B(sum("cash_expected_fy25plus_B", term)), "cash still expected on terminated awards", "FY2025+, as scheduled on 20 Jan 2025"]
];
document.getElementById("tiles").innerHTML = tiles.map(t => `<div class="tile"><div class="v">${t[0]}</div><div class="l">${t[1]}</div><div class="d">${t[2]}</div></div>`).join("");

document.getElementById("lede").innerHTML =
  `Of ${fmt.n(C25.active)} grants and contracts that nonprofits held on 20 January 2025, <b>${fmt.n(C25.terminated)} (${fmt.p(R25.terminated)}) were terminated</b> within ${D.meta.window_days} days, against ${fmt.p(R23.terminated)} of the 2023 cohort over the same span, about <b>${fmt.n(excessTerm)} more terminations than the baseline rate predicts</b>. Counting reductions and stalls as well, ${fmt.n(C25.disrupted)} active awards (${fmt.p(R25.disrupted)}) show some disruption, against ${fmt.p(R23.disrupted)} in 2023. The broad measure moves much less than terminations do, because routine reductions (early de-obligations, ceiling cuts) were <em>less</em> common in 2025 than in 2023.`;
document.getElementById("finding1").innerHTML =
  `<strong>Termination is where 2025 differs from normal.</strong> Formal terminations rose from ${fmt.n(C23.terminated_formal)} to ${fmt.n(C25.terminated_formal)} awards (${fmt.x(R25.terminated_formal / R23.terminated_formal)}); quiet truncations, where the end date is simply moved to "now", nearly doubled, from ${fmt.n(C23.terminated_quiet)} to ${fmt.n(C25.terminated_quiet)}. Reductions fell (${fmt.n(C23.reduced)} → ${fmt.n(C25.reduced)}) and stalls barely moved (${fmt.n(C23.stalled)} → ${fmt.n(C25.stalled)}).`;

pairedBars(document.getElementById("c-signals"), [
  ["Terminated, formal", "terminated_formal"], ["Terminated, quiet truncation", "terminated_quiet"], ["Reduced", "reduced"], ["Stalled", "stalled"],
  ["Any disruption", "disrupted"], ["— termination code (contracts)", "term_code"], ["— termination language", "term_text"],
  ["— end date cut", "end_cut"], ["— early de-obligation", "early_deob"], ["— ceiling cut", "ceiling_cut"],
  ["— missed continuation", "missed_continuation"], ["— stop-work language", "stop_work"], ["— extension", "extension"],
  ["— recipient change", "recipient_change"]
].map(([label, k]) => ({ label, a: R23[k], b: R25[k],
  tip: `<b>${label.replace("— ", "")}</b><br>2023: ${fmt.p(R23[k], 2)} (${fmt.n(C23[k])} awards)<br>2025: ${fmt.p(R25[k], 2)} (${fmt.n(C25[k])} awards)` })), { labelW: 215, max: 24 });
document.getElementById("signals-text").innerHTML =
  `Extensions stayed the most common schedule change (${fmt.p(R25.extension)} in 2025, ${fmt.p(R23.extension)} in 2023): agencies were not extending the awards they slowed. Missed continuations, the signal for annually funded awards whose next year's money did not arrive, rose only slightly overall (${fmt.p(R23.missed_continuation)} → ${fmt.p(R25.missed_continuation)}), but sharply at a few agencies (below).`;

const mo = D.term_months.map(r => ({ label: r.month.slice(2).replace("-", "/"), v: r.N, tip: `<b>${r.month}</b><br>${fmt.n(r.N)} awards first formally terminated` }));
columns(document.getElementById("c-months"), mo, { every: 2, annotate: r => r.v === Math.max(...mo.map(m => m.v)) });
const peak = D.term_months.reduce((a, b) => b.N > a.N ? b : a);
const firstHalf = D.term_months.filter(r => r.month <= "2025-06").reduce((s, r) => s + r.N, 0);
const allT = D.term_months.reduce((s, r) => s + r.N, 0);
document.getElementById("months-text").innerHTML =
  `Formal terminations came in a wave: ${fmt.n(firstHalf)} of ${fmt.n(allT)} (${fmt.p(100 * firstHalf / allT, 0)}) landed between January and June 2025, peaking in ${peak.month} (${fmt.n(peak.N)} awards). After September 2025 they fell to a trickle.`;

const ag = D.by_agency.filter(r => r.active_2025 >= 600 && r.agency_orig !== "Other")
  .map(r => ({ ...r, t23: 100 * r.terminated_2023 / r.active_2023, t25: 100 * r.terminated_2025 / r.active_2025 }))
  .sort((a, b) => b.t25 - a.t25);
dumbbell(document.getElementById("c-agency"), ag.map((r, i) => ({ label: r.agency_orig, a: r.t23, b: r.t25, showLabel: i < 6,
  tip: `<b>${r.agency_orig}</b><br>2023: ${fmt.p(r.t23)} terminated (${fmt.n(r.terminated_2023)} of ${fmt.n(r.active_2023)})<br>2025: ${fmt.p(r.t25)} terminated (${fmt.n(r.terminated_2025)} of ${fmt.n(r.active_2025)})` })));
table(document.getElementById("t-agency"), [
  { h: "Agency", f: r => r.agency_orig },
  { h: "Active 2025", f: r => fmt.n(r.active_2025) },
  { h: "Terminated 2023 → 2025", f: r => `${fmt.n(r.terminated_2023)} → <b>${fmt.n(r.terminated_2025)}</b>` },
  { h: "Reduced 2023 → 2025", f: r => `${fmt.n(r.reduced_2023)} → ${fmt.n(r.reduced_2025)}` },
  { h: "Stalled 2023 → 2025", f: r => `${fmt.n(r.stalled_2023)} → ${fmt.n(r.stalled_2025)}` },
  { h: "Any disruption 2023 → 2025", f: r => `${fmt.p(r.pct_2023)} → <b>${fmt.p(r.pct_2025)}</b>` },
  { h: "Excess awards vs 2023 rate", f: r => r.excess_awards > 0 ? `<span class="up">+${fmt.n(r.excess_awards)}</span>` : fmt.n(r.excess_awards) }
], [...D.by_agency].sort((a, b) => b.excess_awards - a.excess_awards));
const g = k => D.by_agency.find(r => r.agency_orig === k);
const st = g("State"), ua = g("USAID"), ep = g("EPA"), ed = g("Education"), hh = g("HHS"), ns = g("NSF");
document.getElementById("agency-text").innerHTML =
  `The agencies at the center of 2025's policy changes stand out. <b>State</b> went from ${fmt.p(st.pct_2023)} to ${fmt.p(st.pct_2025)} of active awards disrupted (${fmt.n(st.terminated_2025)} terminations, against ${fmt.n(st.terminated_2023)}), <b>USAID</b> from ${fmt.p(ua.pct_2023)} to ${fmt.p(ua.pct_2025)}, with missed continuations the largest category (${fmt.n(ua.stalled_2025)} stalled), and <b>EPA</b> from ${fmt.p(ep.pct_2023)} to ${fmt.p(ep.pct_2025)}. <b>Education</b> quadrupled (${fmt.p(ed.pct_2023)} → ${fmt.p(ed.pct_2025)}), almost all as stalled continuations. <b>HHS</b>, the largest funder, terminated ${fmt.n(hh.terminated_2025)} awards against ${fmt.n(hh.terminated_2023)}, but its broad disruption rate <em>fell</em> because reductions dropped by half (${fmt.n(hh.reduced_2023)} → ${fmt.n(hh.reduced_2025)}); <b>NSF</b> terminations more than doubled (${fmt.n(ns.terminated_2023)} → ${fmt.n(ns.terminated_2025)}).`;

table(document.getElementById("t-dollars"), [
  { h: "Category (2025 cohort)", f: r => r.category === "none" ? "Not disrupted" : r.category[0].toUpperCase() + r.category.slice(1) },
  { h: "Awards", f: r => fmt.n(r.awards) },
  { h: "Organizations", f: r => fmt.n(r.orgs) },
  { h: "Obligated at T0", f: r => fmt.B(r.oblig_to_T0_B) },
  { h: "Cash at stake, FY25+", f: r => fmt.B(r.cash_expected_fy25plus_B) },
  { h: "De-obligated in window", f: r => fmt.M(r.deob_in_window_M) },
  { h: "Ceiling cut", f: r => fmt.M(r.ceiling_cut_M) }
], [...dis.map(c => dol[c]), dol["none"]].filter(Boolean));
const dT = D.dollars_base.filter(r => term.includes(r.category));
document.getElementById("finding2").innerHTML =
  `<strong>Terminated awards carried ${fmt.B(sum("oblig_to_T0_B", term))} in obligations and ${fmt.B(sum("cash_expected_fy25plus_B", term))} in cash still expected to arrive.</strong> Formal terminations recovered little of it: ${fmt.M(dol["terminated (formal)"].deob_in_window_M)} was de-obligated on formally terminated awards, ${fmt.p(100 * dol["terminated (formal)"].deob_in_window_M / 1000 / dol["terminated (formal)"].oblig_to_T0_B, 0)} of their obligations. All disrupted awards together carried ${fmt.B(sum("oblig_to_T0_B", dis))} obligated and ${fmt.B(sum("cash_expected_fy25plus_B", dis))} of expected cash. In the 2023 cohort, terminated awards carried ${fmt.B(dT.reduce((s, r) => s + r.oblig_to_T_B, 0))}.`;

const bs = D.by_size.filter(r => r.size !== "unknown");
const ox = Object.fromEntries(D.org_exposure.map(r => [r.size, r]));
table(document.getElementById("t-size"), [
  { h: "Size", f: r => r.size },
  { h: "Active awards 2025", f: r => fmt.n(r.active_2025) },
  { h: "Terminated 2023 → 2025", f: r => `${fmt.n(r.terminated_2023)} → <b>${fmt.n(r.terminated_2025)}</b>` },
  { h: "Terminated share 2023 → 2025", f: r => `${fmt.p(100 * r.terminated_2023 / r.active_2023)} → <b>${fmt.p(100 * r.terminated_2025 / r.active_2025)}</b>` },
  { h: "Any disruption 2023 → 2025", f: r => `${fmt.p(r.pct_2023)} → <b>${fmt.p(r.pct_2025)}</b>` },
  { h: "Orgs with an active award", f: r => fmt.n(ox[r.size].orgs_active) },
  { h: "…with ≥1 disrupted", f: r => `${fmt.n(ox[r.size].orgs_any_disrupted)} (${fmt.p(ox[r.size].pct_orgs_any)})` },
  { h: "…every award disrupted", f: r => fmt.n(ox[r.size].orgs_all_awards_disrupted) }
], bs);
const sm = bs.find(r => r.size === "small"), md = bs.find(r => r.size === "medium"), lg = bs.find(r => r.size === "large");
document.getElementById("size-text").innerHTML =
  `Large organizations hold ${fmt.p(100 * lg.active_2025 / C25.active, 0)} of active awards, and their broad disruption rate barely moved (${fmt.p(lg.pct_2023)} → ${fmt.p(lg.pct_2025)}). The change is proportionally largest for <b>small organizations</b>: terminations went from ${fmt.n(sm.terminated_2023)} to ${fmt.n(sm.terminated_2025)} awards (${fmt.x((sm.terminated_2025 / sm.active_2025) / (sm.terminated_2023 / sm.active_2023))} the rate), and any disruption from ${fmt.p(sm.pct_2023)} to ${fmt.p(sm.pct_2025)}. Small organizations also hold few awards, so a disruption is more often total: ${fmt.n(ox.small.orgs_all_awards_disrupted)} small organizations saw <em>every</em> active award disrupted, against ${fmt.n(ox.large.orgs_all_awards_disrupted)} large ones.`;

table(document.getElementById("t-top"), [
  { h: "Organization", cls: "wrap", f: r => r.org || "–" },
  { h: "Agency", f: r => r.agency_orig },
  { h: "Type", f: r => r.award_family },
  { h: "Category", f: r => `<span class="pill ${r.category.startsWith("term") ? "t" : ""}">${r.category}</span>` },
  { h: "Obligated at T0", f: r => fmt.M(r.oblig_T_M) },
  { h: "Cash at stake", f: r => fmt.M(r.stake_M) },
  { h: "De-obligated", f: r => fmt.M(r.deob_M) },
  { h: "Award", cls: "keycol", f: r => `<span class="mono">${r.award_key}</span>` }
], D.top_awards.slice(0, 20));

{
  const cov = Object.fromEntries(P.coverage.map(r => [r.group, r]));
  const G = { term: "Terminated", stall: "Stalled", red: "Reduced", ctl: "Not disrupted (control)" };
  const dis3 = [G.term, G.stall, G.red];
  document.getElementById("p-cov").textContent =
    `${fmt.n(dis3.reduce((s, g) => s + cov[g].with_filec, 0))} of ${fmt.n(dis3.reduce((s, g) => s + cov[g].awards, 0))} disrupted awards and ${fmt.n(cov[G.ctl].with_filec)} of ${fmt.n(cov[G.ctl].awards)} control awards (${fmt.n(P.control.certainty)} with at least $2M of expected cash, all taken, plus a random ${fmt.n(P.control.random)} of the rest) returned account-level records.`;
  document.getElementById("p-pop").textContent = fmt.n(P.control.certainty + P.control.random * P.control.weight);
  const qlab = ["Oct–Dec", "Jan–Mar", "Apr–Jun", "Jul–Sep"][P.last_q.fq - 1] + " " + (P.last_q.fq === 1 ? P.last_q.fy - 1 : P.last_q.fy);
  document.getElementById("p-lastq").textContent = qlab;
  const ser = [[G.term, "var(--s-term)"], [G.stall, "var(--s-stall)"], [G.red, "var(--s-red)"], [G.ctl, "var(--base)"]].map(([g, c]) => ({
    name: g === G.ctl ? "Control" : g, color: c, dash: g === G.ctl ? "5 4" : null,
    pts: P.nocash.filter(r => r.group === g).sort((a, b) => a.q - b.q).map(r => ({ label: r.label, v: r.no_cash, n: r.awards }))
  }));
  const qs = ser[0].pts.map(p => p.label);
  lines(document.getElementById("c-nocash"), ser, { max: 80, marker: qs.indexOf("Jan–Mar 2025") - 0.36 });
  const nc = (g, l) => P.nocash.find(r => r.group === g && r.label === l).no_cash;
  const L = qs[qs.length - 1];
  document.getElementById("nocash-text").innerHTML =
    `Before 20 January 2025 the four groups looked alike: in October–December 2024, ${fmt.p(nc(G.term, "Oct–Dec 2024"), 0)} of later-terminated awards and ${fmt.p(nc(G.ctl, "Oct–Dec 2024"), 0)} of control awards received no cash, which is ordinary billing lumpiness. Then they split. By ${L}, <b>${fmt.p(nc(G.term, L), 0)} of terminated awards</b> and <b>${fmt.p(nc(G.stall, L), 0)} of stalled awards</b> that were still scheduled to be running received nothing, against ${fmt.p(nc(G.ctl, L), 0)} of the control. Reduced awards rose more modestly (${fmt.p(nc(G.red, "Oct–Dec 2024"), 0)} → ${fmt.p(nc(G.red, L), 0)}): a reduction shrinks an award, it does not stop it.`;
  const F = Object.fromEntries(P.paid.map(r => [r.group, r]));
  table(document.getElementById("t-flow"), [
    { h: "Group", f: r => r.group }, { h: "Awards", f: r => fmt.n(r.awards) },
    { h: "Outlays 2024", f: r => fmt.B(r.pre_B) }, { h: "Outlays Jul 2025–Jun 2026", f: r => fmt.B(r.post_B) },
    { h: "Change", f: r => { const c = 100 * (r.ratio - 1); return c < 0 ? `<span class="up">${c.toFixed(0)}%</span>` : "+" + c.toFixed(0) + "%"; } },
    { h: "Awards whose cash fell by half or more", f: r => fmt.p(r.pct_fell_by_half) },
    { h: "Awards with no cash after", f: r => fmt.p(r.pct_no_cash_after) }
  ], [G.term, G.stall, G.red, G.ctl].map(g => F[g]));
  document.getElementById("finding3").innerHTML =
    `<strong>Payments on terminated and stalled awards fell while comparable awards grew.</strong> On undisrupted awards scheduled to keep running, outlays rose ${fmt.p(100 * (F[G.ctl].ratio - 1), 0)} from 2024 to the year to June 2026, the normal ramp-up of multi-year awards. On terminated awards they fell ${fmt.p(100 * (1 - F[G.term].ratio), 0)} and on stalled awards ${fmt.p(100 * (1 - F[G.stall].ratio), 0)}; ${fmt.p(F[G.term].pct_fell_by_half, 0)} of terminated awards lost at least half their cash flow, against ${fmt.p(F[G.ctl].pct_fell_by_half, 0)} of the control. Terminated awards were not all cut off. Many kept drawing down money already obligated, which is how close-out works; ${fmt.p(F[G.term].pct_no_cash_after, 0)} received nothing at all.`;
  const S = Object.fromEntries(P.stopped.map(r => [r.group, r]));
  table(document.getElementById("t-stopped"), [
    { h: "Group", f: r => r.group }, { h: "Eligible awards (sampled)", f: r => fmt.n(r.eligible) },
    { h: "Stopped paying", f: r => `<b>${fmt.p(r.pct_stopped)}</b>` },
    { h: "Awards stopped (estimated)", f: r => fmt.n(r.est_awards_stopped) },
    { h: "Unpaid at 20 Jan 2025, on stopped awards", f: r => fmt.B(r.remaining_on_stopped_B) }
  ], [G.term, G.stall, G.red, G.ctl].map(g => S[g]));
  const ca = P.stopped_agency.filter(r => r.group === G.ctl);
  const sa = k => ca.find(r => r.agency_orig === k);
  document.getElementById("stopped-text").innerHTML =
    `The control group is the surprise. Among undisrupted awards, ${fmt.p(S[G.ctl].pct_stopped)} of eligible awards stopped paying, an estimated ${fmt.n(S[G.ctl].est_awards_stopped)} awards with ${fmt.B(S[G.ctl].remaining_on_stopped_B)} still owed that no ledger flag caught. The count is rough: most of it rests on ${P.stopped_ctl_strata.random_sampled} sampled small awards (each standing for ${P.control.weight.toFixed(0)}), so it carries roughly ±30% sampling error, and there is no 2023 payment baseline to say how many small awards stop billing in a normal year. The dollars are firmer, because large awards were all sampled: <b>State and USAID grants hold ${fmt.p(P.stopped_ctl_state_usaid_share, 0)} of the unpaid money on stopped undisrupted awards</b>. Every eligible State award in the sample (${sa("State").eligible} of ${sa("State").eligible}) and ${fmt.p(sa("USAID").pct_stopped, 0)} of USAID awards stopped paying, against ${fmt.p(sa("HHS").pct_stopped, 1)} at HHS and ${fmt.p(sa("NSF").pct_stopped, 1)} at NSF. For State and USAID grants, <b>the ledger understates disruption; outlays are the better measure</b>. The largest of these awards:`;
  table(document.getElementById("t-freeze"), [
    { h: "Organization", cls: "wrap", f: r => r.org || "–" }, { h: "Agency", f: r => r.agency_orig },
    { h: "Obligated", f: r => fmt.M(r.oblig_T_M) }, { h: "Paid by 20 Jan 2025", f: r => fmt.M(r.outlaid_T0_M) },
    { h: "Unpaid", f: r => `<b>${fmt.M(r.remaining_M)}</b>` }, { h: "Scheduled end", f: r => r.sched_end },
    { h: "Award", cls: "keycol", f: r => `<span class="mono">${r.award_key}</span>` }
  ], P.freeze_candidates.slice(0, 12));
  const gg = P.ggrf[0];
  document.getElementById("ggrf-text").innerHTML =
    `<b>The Greenhouse Gas Reduction Fund is the opposite case.</b> File C shows the eight awards' ${fmt.B(gg.oblig_B)} paid out <em>in full</em> by December 2024 (${fmt.B(gg.outlaid_T0_B)} outlaid before 20 January 2025, ${fmt.B(gg.outlaid_post_B)} after). Whatever happened to that money in 2025 happened after it left the Treasury, so neither the award ledger nor federal outlays can show it; measuring it would take the recipients' own accounts.`;
}
{
  const F = Object.fromEntries(P.paid.map(r => [r.group, r])), S = Object.fromEntries(P.stopped.map(r => [r.group, r]));
  const nc = (g, l) => P.nocash.find(r => r.group === g && r.label === l).no_cash;
  const L = P.nocash.filter(r => r.group === "Terminated").sort((a, b) => b.q - a.q)[0].label;
  document.getElementById("finding0").innerHTML =
    `<strong>Payments confirm it, and find more.</strong> By ${L}, ${fmt.p(nc("Terminated", L), 0)} of terminated and ${fmt.p(nc("Stalled", L), 0)} of stalled awards still scheduled to be running received no cash in the quarter, against ${fmt.p(nc("Not disrupted (control)", L), 0)} of undisrupted awards. Outlays also find awards the ledger missed: an estimated ${fmt.p(S["Not disrupted (control)"].pct_stopped)} of undisrupted awards stopped paying with money still owed (${fmt.B(S["Not disrupted (control)"].remaining_on_stopped_B)} unpaid), half of those dollars on State and USAID grants that show no disruption in the ledger at all.`;
}
