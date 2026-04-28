# CLAUDE.md update plan — three new view sections

**Status:** Ready to execute. All claims below were verified empirically via [setup/test_result_history_probe.sql](setup/test_result_history_probe.sql) sections 1–23 plus a SoftLab test-environment correction. This plan is self-contained — a fresh session can execute it without prior conversation context.

**Target file:** [CLAUDE.md](CLAUDE.md) (the project data dictionary, ~3K lines).

**Goal:** Splice in detailed sections for three views currently listed only in the bottom view-reference tables with one-liners, plus correct one stale claim in the existing `V_P_LAB_TEST_RESULT.STATUS` entry.

---

## Insertion points

CLAUDE.md is organized into a "Frequently Used Views — Full Column Detail" section followed by setup-view detail and a complete view reference. Insert the three new sections at:

1. **`V_P_LAB_TEST_RESULT_HISTORY`** → directly after the existing `V_P_LAB_TEST_RESULT` section, before `V_P_LAB_PENDING_RESULT`. Search anchor: `### V_P_LAB_PENDING_RESULT — Pending test results` — insert above this line.

2. **`V_P_LAB_INTERNAL_NOTE`** → directly after the existing `V_P_LAB_MISCEL_INFO` section, before `V_P_LAB_TUBEINFO`. Search anchor: `### V_P_LAB_TUBEINFO — Specimen tube info (denormalized)` — insert above this line.

3. **`V_S_LAB_CANNED_MESSAGE`** → in the setup-view cluster, directly after `V_S_LAB_TEST` (the last setup view detailed). Search anchor: `## Blood Bank (SoftBank) Views — Detail` — insert above that header, after the V_S_LAB_TEST section closes.

Also do a small inline edit to the existing `V_P_LAB_TEST_RESULT.STATUS` row — see "Cross-reference fix" at the end.

---

## Section 1 — V_P_LAB_TEST_RESULT_HISTORY

Splice this entire markdown block at insertion point #1.

````markdown
### V_P_LAB_TEST_RESULT_HISTORY — Test result modification history

**36 columns total** — child of `V_P_LAB_TEST_RESULT`, one row per modification event. Volume: ~236 amendments/day, ~7K rows / 30 days, ~80K rows/year. Base table: `LAB.LAB_ATEST_HISTORY`. ~98.7% of amended results have exactly one amendment in a 30-day window; 1.2% have 2 amendments, 0.1% have 3, none have 4+ (measured chain length, not absolute over a result's lifetime).

#### Identity & Joins

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ATEST_AA_ID | NUMBER 22 | FK → V_P_LAB_TEST_RESULT.AA_ID. Base-table column is `ATEST_ATESTHIST` |

#### Modification metadata

| Column | Type | Description |
|--------|------|-------------|
| MOD_DATE / MOD_TIME / MOD_DT | VARCHAR2 / VARCHAR2 / DATE | Modification timestamp (use `MOD_DT`). Numeric pair stored as VARCHAR2 here, not NUMBER as in most other views |
| MOD_TECH | VARCHAR2 16 | Tech who made the modification. **Often a different person from the original verifier** (validated in test-env spot check) |
| MOD_REASON | VARCHAR2 239 | Free-text narrative entered by the amender. **Sparsely populated (~46% of rows)** — half of amendments carry no reason. PHI-adjacent (can carry clinical context like "Patient expired") |
| TYPE | VARCHAR2 11 | **Application-level enum, no DB-side FK** — SCC's compiled binary decides valid values, the database doesn't enforce them. Verified enum (1-year sample): `RMOD` ~59% (Result-value modification — value-change events), `DMOD` ~41% (non-value edit — range/comment/calc-component trigger; standalone DMODs on Final results have 0/1939 prev_diff_curr in a 30-day sample), `REVMOD` <0.1% (review-related, ~2–3 rows/month). No new TYPE values surfaced over a 12× longer window — list is exhaustive in this deployment |

#### Prior-state snapshot (the "before" values)

| Column | Type | Description |
|--------|------|-------------|
| PREV_RESULT | VARCHAR2 40 | **The value before this modification.** 100% populated even on non-value edits — must *compare values* to detect "value changed", not null-check. Carries sentinels: `'.'` = cancelled (CLAUDE.md cancellation rule), `'See Comment'` = actual value lives in PREV_COMMENT |
| PREV_COMMENT | CLOB 4000 | Snapshot of the prior comment text. Carries the actual prior value when `PREV_RESULT='See Comment'`. PHI-dense free text |
| UNITS | VARCHAR2 80 | Units snapshot (~79% populated) |
| RANGE_NORMAL / RANGE_LOW / RANGE_HIGH | VARCHAR2 256/32/32 | Reference range snapshot (~64–70% populated) |
| ABNORMAL_FLAGS | VARCHAR2 4000 | Flag string snapshot (~26% populated — sparse) |
| STATUS | VARCHAR2 12 | **Range classification snapshot** — `Normal` ~40%, blank ~34%, `AbnormalHigh` ~10%, `AbnormalLow` ~9%, `Abnormal` ~3%, `PanicHigh` ~3%, `PanicLow` ~2%, `Panic` <0.1%. **Different enum from V_P_LAB_TEST_RESULT.STATE.** Notably populated here while documented as vestigial on the live result table |
| QC_STATUS | NUMBER 22 | QC overall status snapshot |
| TESTING_WORKSTATION_ID | VARCHAR2 5 | Performing workstation snapshot (~76% populated) |
| POSTED_FLAG | CHAR 1 | Posted indicator snapshot (~53% populated) |
| ISPOSTEDINFO_PRESENT | NUMBER 22 | Posted-info presence flag |
| IS_AUTORESULTED_WITH_DEFAULT | VARCHAR2 1 | Auto-result-with-default flag |
| REFLABID | VARCHAR2 20 | Reference-lab id (~99.9% populated — likely empty-string default rather than real ref-lab IDs; verify with `REFLABID IS NOT NULL AND REFLABID <> ''` predicate before use) |

#### Verification triple snapshot

| Column | Type | Description |
|--------|------|-------------|
| VER_DATE / VER_TIME / VER_DT / VER_TECH | VARCHAR2 / VARCHAR2 / DATE / VARCHAR2 | Verification timestamp + tech, snapshotted at mod time. **This is the ORIGINAL verification** — not the post-amendment one. SCC's report engine pulls from these for the on-print correction notice |

#### Resulting triple snapshot

| Column | Type | Description |
|--------|------|-------------|
| RES_DATE / RES_TIME / RES_DT / RES_TECH | VARCHAR2 / VARCHAR2 / DATE / VARCHAR2 | Resulting timestamp + tech, snapshotted at mod time. RES_TECH ~88% populated; rest near 100% |

#### Vestigial / effectively-vestigial

`INTERPRET_MSG` (0%), `INTERPRETER_AA_ID` (0%), `PANIC_REPEATED_MSG` (0%), `PANIC_REPEATED_ORDER` (0%), `ORGANIZATION_AA_ID` (0.16% — 11 of 7,085 rows). Don't use in queries.

**Notes:**

- **Index access path**: composite index `(ATEST_AA_ID, MOD_DT, AA_ID)` (base-table columns `ATEST_ATESTHIST, ATH_MODDT, AA_ID`). The FK to the result row is the leading column. Lookups by `ATEST_AA_ID` are fast (clean range scan); date-only window scans use index skip-scan, which is fine on this small table but would be slower on a larger one.
- **No FK on `TYPE`** — application-level enum. SCC's compiled binary decides valid values; the database doesn't enforce them. Implication: future SCC versions could emit new TYPE values without schema change. The 1-year enum sample (RMOD/DMOD/REVMOD) is informative, not guaranteed exhaustive forever.
- **`PREV_RESULT` is 100% populated even on non-value edits** — comparing PREV_RESULT to either the next history row's PREV_RESULT or the current `tr.RESULT` is the correct way to detect actual value changes. Null-checks won't work.
- **`PREV_COMMENT` carries real prior values** for narrative-style results where PREV_RESULT='See Comment'. Surface it whenever you'd expose PREV_RESULT.
- **`MOD_TECH` ≠ original `VER_TECH`/`RES_TECH` is common** — the amender is often a different person than the original verifier (validated in test-env spot check).
- **Per-view TYPE enums** — `V_P_LAB_ACT_HISTORY` and `V_P_LAB_TUBE_HISTORY` use `MODCOM` only; the RMOD/DMOD/REVMOD vocabulary is specific to test result history.
- **TYPE values are empirically-decoded only** — no `V_S_*` lookup maps them to human descriptions. The closest-named candidate (`V_S_GCM_CORRECTIONDICT`) turned out to be a typo/spell-check dictionary, unrelated.

#### Corrected-result print-notice behavior (chemistry / general reports)

When a result is corrected, SCC's chemistry/general report engine prints a one-line correction notice in the form:

> `Corrected result; previously reported as {h.PREV_RESULT} on {h.VER_DT date} at {h.VER_DT time} by {h.VER_TECH}`

Verified by test-env amendment + cross-search against `V_S_LAB_CANNED_MESSAGE.TEXT`, `tr.COMMENTS`, `h.MOD_REASON`, `h.PREV_COMMENT`, and `V_P_LAB_INTERNAL_NOTE.NOTE_TEXT` — none of those carry this exact template. Conclusion: **the chemistry/general correction notice is hard-coded in SCC's report engine binary**, generated at print time from history-row fields. The data fields it reads are exposed exactly as documented above (`h.PREV_RESULT`, `h.VER_DT`, `h.VER_TECH`).

Note that the printed timestamp is the **original verification time** (`h.VER_DT`), not the amendment time (`h.MOD_DT`). And the printed tech is the **original verifier** (`h.VER_TECH`), not the amender (`h.MOD_TECH`).

Microbiology reports use a *different* notice ("This is a corrected report. Previously reported as:") — that one IS stored in `V_S_LAB_CANNED_MESSAGE` under IDs `&CORR` and `}CORR` (categories `MICI` and `MICT`). Two correction-notice templates exist in this deployment: hard-coded for chemistry/general, canned-message-driven for microbiology.

#### Sibling live-row signals on V_P_LAB_TEST_RESULT

Two columns on the live result row indicate the result has been amended (verified in test env):

- `tr.STATE = 'Corrected'` — status flipped from Final/Pending
- `tr.EDITED_FLAG = 'Y'` — corresponds to the `E` indicator in the SCC client's status column

Both fire on a freshly-amended row. They're effectively redundant for routine corrections; could diverge on edge cases (e.g., a Final result that got tweaked without flipping STATE).

`tr.UNVERIFIED_DT` is also set on amendment, but for atomic amendments (un-verify and re-verify in the same SCC client action) it equals `tr.VERIFIED_DT` — so the gap is zero in those cases. Only useful as a divergence signal for non-atomic amendments.

#### Reference query

[orders/corrected_results_audit.sql](orders/corrected_results_audit.sql) shows the canonical join pattern: use `LEAD()` over `(PARTITION BY ATEST_AA_ID ORDER BY MOD_DT)` to compute the "new value" at each amendment from the next chronological PREV_RESULT (falling back to current `tr.RESULT` for the latest amendment). Falsely null-checking PREV_RESULT to detect value changes is wrong — see the `RESULT_VALUE_CHANGED` flag in that query for the correct approach using `DECODE()` for null-safe equality.

#### Outstanding verification

- DMOD specific cause — calculated-test component triggers vs comment-only edits vs range edits. The 30-day correlation (DMOD-on-Final = 0% prev_diff_curr) confirms it's a non-value class but doesn't isolate which sub-cause.
- REVMOD semantics — only ~32 rows in 1 year, too rare to characterize beyond "rare review-related modification."
- Whether SCC ever emits TYPE values outside RMOD/DMOD/REVMOD over a longer window than 1 year.
````

---

## Section 2 — V_P_LAB_INTERNAL_NOTE

Splice this entire markdown block at insertion point #2.

````markdown
### V_P_LAB_INTERNAL_NOTE — Internal notes (multi-owner)

**14 columns total** — multi-owner notes table covering patient/stay/order/tube/result-level narrative, prompt responses, and reschedule/cancellation context. Volume: ~975 notes/day, 2.6M total rows over ~10 years (earliest 2016-05). Base table: `LAB.LAB_INTERNAL_NOTE`. **Not a discriminated union** — the five owner FK columns are layered hierarchically, not exclusive (~28% of rows have multiple FKs populated, almost always order + tube together).

#### Identity & Owner FKs

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER 22 | PK (NOT NULL) |
| ORDER_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDER.AA_ID. **Workhorse FK — populated on 99.98% of rows.** Base-table column is `ACT_NOTES` |
| TUBE_AA_ID | NUMBER 22 | FK → V_P_LAB_TUBE.AA_ID. **Secondary — populated on ~28% of rows, almost always alongside ORDER_AA_ID.** Strongly correlated with `NOTE_CATEGORY = 'S'`. Base-table column is `TUBE_NOTES` |
| TEST_RESULT_AA_ID | NUMBER 22 | FK → V_P_LAB_TEST_RESULT.AA_ID. Sparsely populated (~0.07%). Base-table column is `ATEST_NOTES` |
| PATIENT_AA_ID | NUMBER 22 | FK → V_P_LAB_PATIENT.AA_ID. **Effectively vestigial** — populated on 3 of 2.6M rows. Base-table column is `PAT_NOTES` |
| STAY_AA_ID | NUMBER 22 | FK → V_P_LAB_STAY.AA_ID. **Effectively vestigial** — populated on 2 of 2.6M rows. Base-table column is `PLAB_NOTES` |
| RECUR_AA_ID | NUMBER 22 | FK → V_P_LAB_ORDERING_PATTERN.AA_ID. **Vestigial** — 0 of 2.6M rows. Base-table column is `RECUR_NOTES` |

#### Note content & metadata

| Column | Type | Description |
|--------|------|-------------|
| NOTE_TEXT | VARCHAR2 | Note content (PHI-adjacent free text). 100% populated |
| NOTE_CATEGORY | CHAR 1 | Category enum. Verified distribution: `I` (Internal — HIS prompt responses) ~73%, `S` (Specimen — reschedule/tube-level narrative) ~27%, `A` and `R` 2 rows each (observed-but-edge-case). 100% populated |
| NOTE_TECH | VARCHAR2 16 | User who entered the note. **`HIS` (system identity for the HIS interface) dominates at 71.1%** — majority of internal notes are HIS-generated, not user-entered. Remaining 29% spread across ~1,930 distinct users (3-letter initials like `FFL`, `CCR` and longer codes like `CJONES`, `SMCCO`). 100% populated |
| NOTE_DATE / NOTE_TIME / NOTE_DATETIME | NUMBER / NUMBER / DATE | Standard SCC numeric/DATE triple. Use `NOTE_DATETIME` for date predicates. 100% populated |
| NOTE_CANMSG | VARCHAR2 | **Canned-message reference, pipe-prefix convention** — values like `\|R`, `\|RRES`, `\|Y001`, `\|YPLI`, `\|YPRF` reference IDs in `V_S_LAB_CANNED_MESSAGE`. Two prefix families: `\|Y***` (prompt-response codes, e.g., responses to "TS:Is There a Prepare Order for Surgery?") and `\|R*` (Reschedule-related). Populated on ~17% of rows. Single-line canned-codes |

**Notes:**

- **Hierarchical, not exclusive**: practical join pattern for "all notes on an order" is just `JOIN ON note.ORDER_AA_ID = o.AA_ID` — that catches ~all rows (99.98%). Filtering on `TEST_RESULT_AA_ID` or `STAY_AA_ID` would miss almost everything because those FKs are sparse-to-vestigial.
- **`NOTE_CATEGORY='S'` ⇔ `TUBE_AA_ID IS NOT NULL`** correlates strongly (both ~27% of rows) — Specimen-category notes are the tube-level subset.
- **`NOTE_TECH='HIS'` is the singular system persona** — only 2 of the typical SCC system-identity codes (`HIS`, `SCC`, `AUTOV`, `RBS`) are present in this table, and `HIS` accounts for ~99% of the system-generated rows.
- **`NOTE_CANMSG` is a join key into `V_S_LAB_CANNED_MESSAGE`** — strip or preserve the `|` prefix as needed; SCC's canned-message ID convention treats the `|` as part of the message ID itself (see V_S_LAB_CANNED_MESSAGE notes). The pipe-prefixed canned messages are single-line short codes used as enum-like references.
- **Index access**: every owner FK has its own composite index `(<FK>, NOTE_DT, AA_ID)` — including the vestigial ones. Lookups by any owner level are fast (FK is leading column). Schema is forward-compatible: even unused FKs are indexed in case they get populated later.

#### Sample uses observed

- HIS prompt responses (`NOTE_CATEGORY='I'`, `NOTE_TECH='HIS'`): "TS:Is There a Prepare Order for Surgery?->No", "RCL:Transfusion Indications->Hb < 7…"
- Reschedule narratives (`NOTE_CATEGORY='S'`, real user as NOTE_TECH): "Patient Unavailable; Test rescheduled. Collection has been rescheduled at MM/DD/YYYY HH:MM"
- Cancellation context: "do this later", "Patient is a difficult stick, unable to collect specimen"
- Correction-notice text is **not** stored here (verified by direct text search) — chemistry/general correction notices are hard-coded in SCC's report engine; microbiology correction notices live in `V_S_LAB_CANNED_MESSAGE`.

#### Vestigial

`PATIENT_AA_ID`, `STAY_AA_ID`, `RECUR_AA_ID` are functionally unused in this deployment despite being indexed.
````

---

## Section 3 — V_S_LAB_CANNED_MESSAGE

Splice this entire markdown block at insertion point #3.

````markdown
### V_S_LAB_CANNED_MESSAGE — Canned message setup (cross-module shared)

**10 columns total** — the SoftLab view layer over SCC's cross-module canned-message store. Volume: 9,144 rows / 2,418 distinct message IDs, ~3.78 lines per message on average. Base table: `LAB.HLSYS_MESSAGE` (the `HLSYS_` prefix denotes a cross-module SCC system table — other modules likely have their own views over the same base table).

#### Columns

| Column | Type | Description |
|--------|------|-------------|
| AA_ID | NUMBER | PK |
| ID | VARCHAR2 | Message identifier. **Special-character first-character convention** distinguishes system-reserved messages from user-defined: see ID-prefix table below. Base-table column is `MESID` |
| LINE_NUMBER | NUMBER | 0-based line number for multi-line templates. ~45% of messages are single-line (LINE_NUMBER=0 only); ~55% span 2+ lines, with a long tail to 52 lines. Always concatenate by LINE_NUMBER order to assemble full text. Base-table column is `MESLINENO` |
| TEXT | VARCHAR2 | Message text content. May be display text ("Ref.Range not available.") OR SCC's expression/scripting language (`$A:=@MPV->"AGE"/365.25;`, `MATCH("PERFORMED",$@MDIFP)?$@SEGM:$@SEGA`) — the script-language rows are part of SCC's macro/template engine, not human-readable narrative. 100% populated |
| ACTIVE | VARCHAR2 1 | Y/N. ~85% active, ~15% inactive |
| EXP_DATE / EXP_DT | NUMBER / DATE | Expiration date (numeric pair + DATE). ~23% of rows are past their EXP_DT. ACTIVE and EXP_DT are independent dimensions (some active rows have past expiration dates and vice versa). Base-table column is `MESEXDT` |
| NEW_LINE | VARCHAR2 1 | Newline indicator. The only column with any nulls (~16% blank); rest are 100% populated |
| CATEGORY | VARCHAR2 | Category enum — see distribution table below |
| DISCARD_CONTAINER | VARCHAR2 | Discard-container marker (100% populated, semantics unverified) |

#### CATEGORY enum (verified, 18 values)

Top buckets (CATEGORY / row_count / distinct messages / avg lines):

| CATEGORY | Rows | Messages | Avg lines | Notes |
|----------|------|----------|-----------|-------|
| OTHER | 3450 | 979 | 3.5 | Generic / uncategorized — biggest bucket |
| TEST | 2742 | 366 | 7.5 | Test-related canned text. Longest avg messages — narrative-heavy |
| RESUL | 2250 | 693 | 3.2 | Result-related (canned result narratives, panic-call templates) |
| MICI | 260 | 108 | 2.4 | Microbiology Internal/Interim. Holds `&CORR` — micro corrected-report notice |
| MICT | 167 | 102 | 1.6 | Microbiology Test. Holds `}CORR` — alternate micro corrected-report notice |
| REPO | 101 | 26 | 3.9 | Report format |
| OECAN | 36 | 36 | 1.0 | Order-entry cancellation. Single-line each |
| MICD / PHREC / RNG / SPEC / ORDER / MICOE / PHCAN / MICM / STAY / INSUR / OESCH | 1–27 each | <30 each | varies | Edge categories |

Top 3 (OTHER, TEST, RESUL) cover ~93% of rows. Domain-prefix families:
- **MIC*** — Microbiology subcategories (5 categories): MICI, MICT, MICD, MICOE, MICM
- **PH*** — Phlebotomy/Patient: PHREC (Recall), PHCAN (Cancel)
- **STAY**, **INSUR**, **OESCH** — minimal-row edge categories

#### ID prefix convention (system-reserved vs user-defined)

Special-character first character marks system-reserved messages — confirmed pattern across ~31% of rows (~43% of distinct message IDs):

| Prefix | Rows | Distinct messages | Use |
|--------|------|-------------------|-----|
| `@` | 2,250 | 693 | Largest system family. `@CRR` lives here (corrected-result call-back notice) |
| `&` | 260 | 108 | `&CORR` lives here (microbiology corrected-report notice) |
| `}` | 167 | 102 | `}CORR` lives here (alternate microbiology corrected-report notice) |
| `\|` | 136 | 127 | Single-line short codes referenced by `V_P_LAB_INTERNAL_NOTE.NOTE_CANMSG` (`\|R`, `\|RRES`, `\|Y001`, `\|YPLI`, etc.) |
| `#` | 27 | 10 | Smaller system family |
| `{` | 11 | 7 | Smaller system family |

Alphanumeric-prefix IDs (~69% of rows) are user-defined. Notably:
- `T` prefix: 2,742 rows / 366 messages — corresponds heavily with the TEST category
- Numeric prefixes (`1`, `2`, `3`) and rare letters (`X`, `Q`, `O`, `Y`, `Z`) are tail edge cases

#### Indexes (base table HLSYS_MESSAGE)

- `HLSYS_MESSAGE_AA_ID_PK` (UNIQUE) — `AA_ID`
- `HLSYS_MESIDEXP_UNIQ` (UNIQUE) — `(MESID, MESEXDT, MESLINENO)` — composite unique on (ID, expiration date, line number). Same logical message ID can be stored across multiple expiration windows (each version carries its own LINE_NUMBER lines) — this is how SCC versions canned templates over time
- `HLSYS_MESID_INDEX` (NONUNIQUE) — `(MESID, AA_ID)` — for fast lookups by message ID

#### Notes

- **Cross-module shared**: the `HLSYS_` base-table prefix means this is a global SCC resource, not SoftLab-specific. The BloodBank module has its own canned-message setup (`Y_Canned_Message` in legacy SCC docs, `V_S_BB_Y_Canned_Message` in the modern view layer) over a separate base table.
- **TEXT can be either narrative or expression-language** — when filtering for human-readable messages, expect to see SCC macro syntax (`$@VAR`, `$A:=...`, `MATCH(...)?...:...`) mixed in with display strings.
- **Versioning via composite UNIQUE**: the same `ID` + `LINE_NUMBER` can appear multiple times if the rows have different `EXP_DT` values. To get the currently-active version of a multi-line message, filter on `ACTIVE='Y' AND (EXP_DT IS NULL OR EXP_DT >= SYSDATE)` and ORDER BY `LINE_NUMBER`.
- **Join key from V_P_LAB_INTERNAL_NOTE**: `note.NOTE_CANMSG` carries the full pipe-prefixed ID (`|R`, `|RRES`, etc.) — verify whether the `|` is preserved or stripped on the canned-message side before joining.
- **Two correction-notice families coexist** in this deployment: chemistry/general uses a hard-coded template (not stored here); microbiology uses canned messages (`&CORR` / `}CORR` here). See V_P_LAB_TEST_RESULT_HISTORY notes for the full correction-notice landscape.
````

---

## Cross-reference fix — V_P_LAB_TEST_RESULT.STATUS clarification

The existing `V_P_LAB_TEST_RESULT` section currently documents `STATUS` as:

> `STATUS | VARCHAR2 12 | Empty in samples — vestigial, use STATE`

Update to:

> `STATUS | VARCHAR2 12 | Empty on the live row — vestigial here, use STATE. Note: the same column on V_P_LAB_TEST_RESULT_HISTORY IS populated (range classification snapshot at mod time: Normal/AbnormalHigh/AbnormalLow/etc.) — see V_P_LAB_TEST_RESULT_HISTORY for that enum`

Locate via the search anchor `STATUS | VARCHAR2 12 | Empty in samples — vestigial, use STATE` and replace.

---

## Validation checklist

After splicing, the executing agent should verify:

1. **Anchor preserved**: each insertion point's anchor line still exists immediately after the new section ends. Re-read CLAUDE.md around each insertion to confirm no accidental overlap with the next section.
2. **Markdown table rendering**: the embedded tables use `|` separators that don't conflict with the `\|` escapes in canned-message references (`\|R`, `\|RRES`). Confirm by grepping `^\|.*\|.*\|.*$` patterns near the new sections.
3. **Cross-references work**: the V_P_LAB_TEST_RESULT_HISTORY section references `[orders/corrected_results_audit.sql](orders/corrected_results_audit.sql)` — confirm that file exists.
4. **The complete-view-reference table at the bottom of CLAUDE.md already lists all three views with one-liners** — no need to update those entries; they're fine as quick-lookup pointers and the new detailed sections supplement them.
5. **No PHI introduced**: this plan was scrubbed of test-patient identifiers and real result samples. Confirm the spliced sections contain only aggregate findings, enum values, column descriptions, and the system-identity codes (HIS, SCC, AUTOV — all known operational, not PHI).
6. **Cross-cutting rules unchanged**: the existing "Cross-Cutting Query Rules" section (Valid MRN filter, etc.) needs no edit — these are read-time rules independent of the new view documentation.

## Source-of-truth for every claim

Every empirical claim above traces to a section of [setup/test_result_history_probe.sql](setup/test_result_history_probe.sql):

| Claim | Source |
|-------|--------|
| V_P_LAB_TEST_RESULT_HISTORY volume / chain length | §1, §7 |
| TYPE enum (RMOD/DMOD/REVMOD with %) | §2 (30-day), §23 (1-year confirmation) |
| STATUS enum (range classification snapshot) | §3 |
| Population rates / vestigial columns | §4 |
| Indexes on LAB_ATEST_HISTORY | §5 |
| TYPE × STATE correlation (RMOD = value-change, DMOD = non-value) | §6 |
| Sibling history views use MODCOM, different enum | §11a, §11b |
| No FK on TYPE → application-level enum | §9d |
| No comment-decode for TYPE in SCC dictionary | §9b, §9c, §10 |
| V_P_LAB_INTERNAL_NOTE volume | §12 |
| Hierarchical (not exclusive) FK pattern | §13 |
| NOTE_CATEGORY enum | §14 |
| NOTE_TECH HIS dominance | §15a, §15b |
| NOTE_CANMSG pipe-prefix family | §16a |
| Per-FK indexes on LAB_INTERNAL_NOTE | §16b |
| V_S_LAB_CANNED_MESSAGE volume | §17 |
| Population rates | §18 |
| CATEGORY enum (18 values) | §19 |
| ID-prefix system-vs-user convention | §20 |
| Multi-line distribution | §21 |
| Indexes on HLSYS_MESSAGE / composite UNIQUE | §22 |

The chemistry/general print-template hard-coding finding (in V_P_LAB_TEST_RESULT_HISTORY notes) traces to a test-environment correction in the SoftLab test instance + cross-search of `V_S_LAB_CANNED_MESSAGE.TEXT`, `tr.COMMENTS`, `h.MOD_REASON`, `h.PREV_COMMENT`, and `V_P_LAB_INTERNAL_NOTE.NOTE_TEXT` — all five returned zero matches for "previously reported", confirming the template isn't stored. Microbiology canned messages `&CORR` / `}CORR` were the only correction-notice templates surfaced in any database column.
