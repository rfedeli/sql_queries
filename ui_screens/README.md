# UI Screens — Field-to-Column Reference

Markdown documentation linking SCC application screens to the database columns they read/write. Each screen has its own file with:

1. **Embedded screenshot** of the actual UI (perfect-fidelity layout)
2. **Field-to-column tables** mapping each visible label to its database column
3. **Cross-links** to [claude.md](../claude.md) for column detail and to [schema_diagrams.md](../schema_diagrams.md) for entity relationships
4. **TBD list** at the bottom for fields whose columns aren't yet confidently mapped

The pattern: someone who sees a field on a screen can find the column to query; someone reading SQL can find where the value comes from in the app.

## Workflow for adding a new screen

1. Take a screenshot of the screen with a representative test patient open
2. Save it to `ui_screens/<screen_name>_screen.png` (or `.jpg`)
3. Create or update `ui_screens/<screen_name>.md` with:
   - Header (module, mode, tables touched)
   - `![alt](<screen_name>_screen.png)` reference
   - Field-to-column tables (one per logical UI section)
   - TBD list for unmapped fields
4. Commit screenshot + markdown together so the embed renders

## Screens documented

### SoftLab

- [order_entry.md](order_entry.md) — Patient Order screen (combined patient/stay/order/orderables tabbed form)

### SoftAR
*(none yet — candidates: Visit Inquiry, Item Edit, Billing Errors browser)*

### SoftBank
*(none yet — candidates: BB Order, Crossmatch, Unit Inquiry)*

### SoftMic
*(none yet — candidates: Micro Order Entry, Result Entry, Sensitivity Panel)*

## Conventions

- **Screenshots use placeholder/test data** when possible (TX-prefix MRNs, fake names) so PHI doesn't land in the repo
- **Field-to-column tables** are the authoritative reference — the screenshot is for visual context only. If the screenshot ever drifts from current SCC behavior, the tables are still queryable
- **TBD markers** are fine and expected — they're a queue for follow-up discovery passes, not a blocker
- **Per-section tables** keep things scrollable; one giant table per screen would be unreadable
