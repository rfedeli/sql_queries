# Discovery Templates — Reusable Probes for SCC Schema Investigation

Reusable SQL templates for investigating SCC views and verifying hypotheses. Replaces the iterative 5-query manual discovery pattern we've been using with **one comprehensive deep probe** plus **three targeted verification templates** for the hypothesis shapes that recur most often.

**Why this exists:** across ~10 view discoveries this session, the same patterns kept emerging late (vestigial columns, duplicate-named columns, hidden enums, numeric/DATE triples, counter-intuitive FKs, null-handling gotchas). The old template surfaced these one at a time across 5 manual queries; the deep probe surfaces all of them in a single run. The verification templates encode the three crosstab/join shapes we used most — STATUS×date correlation, parent-child component fanout, duplicate-column equivalence.

**Where this fits:** these templates are tooling for *running* discoveries, not the discoveries themselves. One-off discovery files (e.g., `bb_result_view_discovery.sql`) still get created, used, and deleted per session. These templates persist.

---

## ⚠️ Operational risk — this is a PRODUCTION clinical database

These templates query the live SCC LIS supporting active patient care. Treat every probe as a potential operational impact, not a sandbox query. Concrete guardrails:

### Performance / load risk

- **`V_P_LAB_TEST_RESULT` is ~60M rows/year, ~162K rows/day.** A bad query against it can degrade response time for clinical staff entering results. The deep probe's distinct-count and population-rate sections are the most expensive — both involve full-column aggregates.
- **Always window your aggregates** with a tight date predicate on an indexed timestamp column (`TEST_DT`, `VERIFIED_DT`, `RECEIPT_DT`, etc.). Default in templates: **7 days for V_P_LAB_TEST_RESULT, 30 days for everything else.** Widen only when results are sparse.
- **Test the template on a small view FIRST** — V_P_LAB_TUBEINFO (13 cols, ~9.8K rows/day) before running it on V_P_LAB_TEST_RESULT (242 cols, ~162K rows/day). If a section misbehaves on the small view, fix it before scaling up.
- **`COUNT(DISTINCT col)` is expensive at scale** — the deep probe limits this to small VARCHAR/CHAR columns where enum detection actually matters; don't naively apply it to every column.
- **Avoid running during peak clinical hours** when possible (typical morning labs 06:00–10:00, post-shift documentation 16:00–18:00). Off-hours runs reduce contention.

### Read-only discipline

- **Templates are SELECT-only by design.** No `INSERT`/`UPDATE`/`DELETE`/`MERGE`/`TRUNCATE`/`ALTER` ever appears in them. If you find yourself editing one to do anything other than SELECT, stop — that's not a discovery, it's a mutation, and it doesn't belong in this directory.
- **No transaction state changes** — no `COMMIT`/`ROLLBACK`/`SAVEPOINT` in templates. Discovery doesn't need them.

### Abort / kill-switch awareness

- **Know how to cancel** a running query in your Oracle client before launching anything heavy. If a section hangs (e.g., a forgotten date filter), you need a fast escape.
- **Set a session timeout** if your client supports it (e.g., SQL Developer "SQL Timeout"). Five minutes is generous for any reasonable discovery.

### PHI / data-handling risk

- **Sample rows contain real PHI** — MRNs, names, DOBs, diagnoses, free-text comments. Per the `feedback_obfuscate_queried_data.md` memory rule, **never paste raw sample-row output into shared docs, the dictionary, GitHub commit messages, or external chat tools**. When sharing for analysis, replace identifiers with placeholders (`E*******`, `LASTNAME, FIRSTNAME`).
- **Free-text fields are high-PHI-density** — `V_P_LAB_CANCELLATION.REASON`, `V_P_LAB_STAY.DIAGNOSIS_TEXT`, `V_P_LAB_ORDER.NOTES`/`COMMENTS`, `V_P_BB_Result.RESULT_COMMENT` (when populated), and any CLOB column. Treat as PHI-adjacent even when the column name doesn't suggest it.
- **Cardinality probes (group-by) on free-text fields can leak PHI by way of low-frequency unique values.** A `REASON` value appearing once might still contain a patient or staff name. Apply `TRIM(UPPER(...))` and aggregate carefully.

### Schema-scope risk

- **Default `ALL_TAB_COLUMNS` matches views across all schemas the session can read.** Templates filter by `UPPER(TABLE_NAME)` — but if a name collides across schemas, you'll get duplicate rows. When in doubt, also filter by `OWNER` (the SCC LIS owner is typically `LAB`, `BB`, or similar — confirm in your environment).

### Permissions

- Discovery templates require read access to: the target view itself, plus `ALL_TAB_COLUMNS`, `ALL_INDEXES`, `ALL_IND_COLUMNS`, and (if Section F lands) `USER_COL_COMMENTS`/`ALL_COL_COMMENTS`. If a section errors with `ORA-00942: table or view does not exist` on a metadata view, that's typically a permission issue and the section can be skipped.

### Auditing

- Production Oracle environments often have query auditing enabled (Unified Auditing, FGA, or HIPAA audit logging). Discovery queries may be logged. This is normal and not a privacy issue for read-only metadata/sample probes — but it does mean experimental query iteration leaves a trail. Be deliberate.

### Bottom line

The discovery template's job is to extract structural truth, not to test database limits. **If a probe takes more than ~30 seconds against a properly-windowed dataset, kill it and rewrite — that's a sign the date filter isn't using an index, or you're scanning more rows than you intended.**

---

## Files in this directory

| File | Purpose | When to use |
|------|---------|-------------|
| `README.md` | This file | Always read first |
| `view_deep_probe.sql` | Comprehensive single-view scan: column list, population rates, distinct-count enum detection, date-triple identification, index info, comments, sample rows, volume | First step for any new view — replaces Q1-Q5 of the old manual template |
| `verify_status_review_correlation.sql` | Two-column correlation crosstab — tests whether one column's values predict another's populated/null state | When you have a workflow-state hypothesis (e.g., "STATUS='C' = reviewed") to falsify or confirm |
| `verify_parent_child_fanout.sql` | Joins parent → child entity and groups by both code columns, surfacing the actual component fanout pattern | When you suspect a parent test/entity produces multiple child rows with different codes (TS3 → ABORH+AS3 pattern) |
| `verify_duplicate_columns.sql` | Tests whether two column names that look like duplicates actually hold the same value | When you spot pairs like `PRIORIY/PRIORITY`, `ORDER_TYPE/ORDERTYPE`, or `RES_HANDLING/RESULT_HANDLING` |

---

## Workflow

```
1. Pick a view to investigate.
   ↓
2. Run view_deep_probe.sql — substitute the view name in the
   SECTION-A query (TABLE_NAME filter); other sections inherit it.
   Read the output. Notice:
     - Vestigial columns (population rate < 1%)
     - Duplicate-name pairs (similar names, both populated)
     - Hidden enums (low distinct counts on small VARCHAR/CHAR cols)
     - Date triples (NUMBER/NUMBER/DATE name patterns)
     - Indexed columns (window-query performance hints)
     - Counter-intuitive FK columns (NUMBER cols ending _AA_ID
       whose values look like AA_IDs of OTHER tables)
   ↓
3. Form hypotheses from the output. Each hypothesis = a claim
   you'd put in CLAUDE.md if true.
   ↓
4. For each hypothesis, pull the matching verification template:
     - "STATUS column means X" → verify_status_review_correlation.sql
     - "Parent test makes N child rows of type Y" → verify_parent_child_fanout.sql
     - "Two columns are duplicates" → verify_duplicate_columns.sql
   Substitute params, run, interpret.
   ↓
5. Fold VERIFIED facts into CLAUDE.md. Mark UNVERIFIED hypotheses
   explicitly (per the test-all-hypotheses memory rule).
   ↓
6. Audit existing queries against the new findings. Fix or flag
   any that depend on now-corrected assumptions.
   ↓
7. Commit + push CLAUDE.md update.
```

---

## Parameter substitution convention

Oracle bind variables (`:name`) work for **values** (dates, codes, IDs) but NOT for **table or column names**. Templates therefore use one of two patterns:

- **Bind variables for values** — `:start_date`, `:test_code`, etc. Substituted at runtime by the SQL client.
- **Literal placeholders for identifiers** — `__VIEW_NAME__`, `__COL_A__`, `__PARENT_TABLE__`, etc. **Edit these directly in the SQL before running.** They use a distinctive double-underscore syntax so they're easy to find and replace.

Each template's header comment lists exactly which placeholders to edit, with examples.

---

## Project-rule constraints templates honor

These come from the memory rules — every template respects them:

- **No `FETCH FIRST`** — Oracle client doesn't support it. Use `ROWNUM <= N` inside an `ORDER BY` subquery.
- **No `&` SQL*Plus substitution variables** — client doesn't support them. Use bind variables or edit-the-template literal placeholders.
- **No `COL` as a column alias** — client rejects it. Use `FIELD_NAME` / `VAL` / `N` instead.
- **`UNION ALL` discovery probes wrap in subquery + positional `ORDER BY`** — alias resolution on the outer ORDER BY is fragile. `... ORDER BY 1, 3 DESC` works universally.
- **`-1` is a common "not set" sentinel** for numeric date/time columns. Predicates that use `*_DT` (DATE) instead of `*_DATE`/`*_TIME` (NUMBER) avoid the sentinel-handling.
- **`'NULL'` as literal text** is a real value, distinct from database NULL. Population probes test for both.
- **MRN filter** — when a probe touches `V_P_LAB_PATIENT.ID`, include `REGEXP_LIKE(p.ID, '^E[0-9]+$')` to exclude test/fake patients (unless the goal is finding them).

---

## Folding results into CLAUDE.md

After verification, the dict update pattern is:

1. **Verified facts** → land in the per-view column-detail tables and the **Notes** section.
2. **Falsified hypotheses** → if I'd previously written the wrong claim into the dict, the commit message explicitly says "FALSIFIED" so future readers see the correction.
3. **Unverified-but-plausible** → mark inline with `**Hypothesis (NOT yet verified):**` plus a note of which verification probe would resolve it.
4. **Outstanding work** → at the bottom of each section, an "Outstanding verification work" list identifies what's still inferred. Future sessions can pick from this queue.

Per the `feedback_test_all_hypotheses.md` memory rule, **no claim lands in CLAUDE.md without a directly-verifying query result OR an explicit unverified marker**. The deep probe + verification templates exist so that bar is cheap to clear.

---

## When NOT to use these templates

- **For one-off ad-hoc exploration** of a column you already understand → write a quick query inline; templates are overkill
- **For very small views (< 15 columns)** like V_P_LAB_TUBEINFO → the deep probe is heavier than needed; the old manual 5-query pass is fine
- **For audit-the-codebase tasks** ("which queries use column X?") → use Grep, not these templates
- **When the question is operational, not schema-shape** ("what's the daily order volume right now?") → write a focused query, not a discovery

---

## See also

- `claude.md` (root) — the data dictionary these templates feed
- `schema_diagrams.md` (root) — entity-relationship diagrams
- Memory: `feedback_test_all_hypotheses.md`, `feedback_oracle_union_order_by.md`, `feedback_index_friendly_predicates.md`, `feedback_grapecity_colon_parsing.md`
