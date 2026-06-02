---
name: report-generator
description: >-
  Generate polished, enterprise dashboard-style reports as HTML files (never Markdown).
  Use this skill whenever the user asks for any kind of report or written technical
  deliverable — including status reports, Jira / sprint / release reports, implementation
  reports, investigation reports, bug reports, root cause analyses, review summaries,
  release notes, technical documentation, or project / sprint summaries — even when they
  do not explicitly say "HTML". Trigger it any time a request would otherwise produce a
  plain Markdown report: this skill exists to render reports as a branded admin dashboard
  instead. Do NOT use it for spreadsheets, slide decks, Word/PDF documents, or general
  non-report prose.
---

# Report Generator

Turn report content into a clean, branded, enterprise dashboard-style HTML report instead
of a plain Markdown document. The goal is something that looks like an internal admin
panel: card-based layout, status badges, KPI tiles, readable tables, and a consistent
theme built around the brand color `#fcba03`.

## What "good" looks like

A finished report should feel like a real product dashboard, not a styled text file:

- Clear header with title, ticket/ID, author, date, and a status badge.
- Scannable structure — KPI cards up top, then sections in cards with generous spacing.
- Consistent theming via one shared `index.css`; no styles duplicated across pages.
- Responsive: usable on a laptop and readable on mobile.
- Accurate: it presents only what the user gave you (see "Content rules").

Reading the `frontend-design` skill first is helpful for layout and typographic quality,
but the brand palette below overrides any default accent color that skill suggests.

## Output and file handling

Reports are real files the user will download and open, so:

1. Write reports under `./report/` in the current project (e.g. `./report/JIRA-1234/`).
   Create the `./report/` directory if it does not exist. After building, present the
   folder path so the user can open it. Do **not** write to `/tmp` or `/mnt/user-data/`.
2. Each report lives in its **own directory** under `./report/`, named after the ticket
   or topic (e.g. `./report/JIRA-1234/`), so multiple reports never collide.
3. Multi-file reports use relative links **without a `./` prefix** (`findings.html`, not
   `./findings.html`). The user typically serves the report folder with `npx serve ./report`,
   so pages are reached at `report/[TICKET]/index.html`; bare relative links resolve cleanly
   under the static server and still work when the folder is downloaded and opened directly.
   Present the folder, not a single file.
4. If the user just wants a quick preview in chat, a single self-contained `index.html`
   (with the CSS inlined in a `<style>` block) renders better inline. Default to the
   multi-file structure unless the user signals they only want a quick look.

## File structure

Always create at minimum:

```
JIRA-1234/
├── index.html
└── index.css
```

Add extra pages **only when they improve readability or surface important information** —
splitting a long report into focused pages reduces scrolling and highlights what matters.
Use descriptive filenames:

```
JIRA-1234/
├── index.html              # Overview + executive summary + KPIs
├── index.css               # Shared theme (imported by every page)
├── require-to-review.html  # Items needing reviewer attention
├── findings.html           # Detailed findings
├── technical-analysis.html # Implementation / root cause detail
├── risks.html              # Risk register
└── timeline.html           # Chronology
```

Keep it simple when the content is simple. A two-file report is perfectly good.

## Design system

Define these as CSS variables in `index.css` and reference them everywhere instead of
hard-coding hex values. The neutrals and semantic colors are what make it read as
"enterprise" rather than "one yellow page".

### Color tokens

```css
:root {
  /* Brand */
  --primary: #fcba03;
  --primary-strong: #e0a500; /* hover / pressed */
  --primary-soft: #fff6db; /* tinted backgrounds, KPI accents */
  --on-primary: #1f2937; /* text ON amber — NEVER white, amber+white fails contrast */

  /* Neutrals */
  --bg: #f8fafc; /* page background */
  --surface: #ffffff; /* cards */
  --border: #e2e8f0;
  --text: #1e293b; /* primary text */
  --text-muted: #64748b; /* secondary text */

  /* Semantic (status badges, alerts) */
  --success: #166534;
  --success-bg: #dcfce7;
  --warning: #9a3412;
  --warning-bg: #ffedd5;
  --danger: #991b1b;
  --danger-bg: #fee2e2;
  --info: #1e40af;
  --info-bg: #dbeafe;
}
```

**Contrast rule:** `#fcba03` is bright yellow. Always put dark text (`--on-primary`) on
amber fills — buttons, active nav, highlighted KPI tiles. White text on amber is unreadable.

### Status badge convention

Map status to color so badges are consistent across the whole report:

- Done / Resolved → `--success`
- In Progress / Active → brand amber (`--primary` fill, `--on-primary` text)
- At Risk / Warning → `--warning`
- Blocked / Critical → `--danger`
- Open / Info → `--info`

### Typography & spacing

Use a system/Inter stack, semibold headings, comfortable line-height (~1.6 for body),
and consistent card padding (`1.5rem`). Prefer whitespace over borders to separate sections.

## Shared CSS starter (`index.css`)

Generate one reusable stylesheet. Put theme variables and reusable component classes here;
let Tailwind utility classes handle the rest. Suggested starting point:

```css
:root {
  /* paste the color tokens from above here */
}

body {
  background: var(--bg);
  color: var(--text);
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    "Segoe UI",
    sans-serif;
  line-height: 1.6;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 0.75rem;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  padding: 1.5rem;
}

.kpi-card {
  border-top: 3px solid var(--primary);
}
.kpi-value {
  font-size: 1.875rem;
  font-weight: 700;
  line-height: 1.1;
}
.kpi-label {
  color: var(--text-muted);
  font-size: 0.8125rem;
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
}
.badge--success {
  background: var(--success-bg);
  color: var(--success);
}
.badge--warning {
  background: var(--warning-bg);
  color: var(--warning);
}
.badge--danger {
  background: var(--danger-bg);
  color: var(--danger);
}
.badge--info {
  background: var(--info-bg);
  color: var(--info);
}
.badge--active {
  background: var(--primary);
  color: var(--on-primary);
}

.btn-primary {
  background: var(--primary);
  color: var(--on-primary);
  font-weight: 600;
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
}
.btn-primary:hover {
  background: var(--primary-strong);
}

.report-nav {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.report-nav a {
  padding: 0.5rem 0.875rem;
  border-radius: 0.5rem;
  color: var(--text-muted);
  font-weight: 500;
  text-decoration: none;
}
.report-nav a:hover {
  background: var(--primary-soft);
  color: var(--text);
}
.report-nav a.active {
  background: var(--primary);
  color: var(--on-primary);
}

table {
  width: 100%;
  border-collapse: collapse;
}
th {
  text-align: left;
  color: var(--text-muted);
  font-size: 0.8125rem;
  padding: 0.75rem;
  border-bottom: 1px solid var(--border);
}
td {
  padding: 0.75rem;
  border-bottom: 1px solid var(--border);
}
tr:hover td {
  background: var(--primary-soft);
}
```

Every HTML page imports it and does not redefine these styles. The stylesheet path depends
on the page: **`index.html` uses `./index.css`** (with the `./` prefix), while **every other
page uses a bare relative path** (`index.css`, no prefix) so it resolves correctly when the
folder is served with `npx serve ./report`:

```html
<!-- index.html -->
<link rel="stylesheet" href="./index.css" />

<!-- all other pages (findings.html, risks.html, …) -->
<link rel="stylesheet" href="index.css" />
```

## Page template

Every page starts from this shell:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- index.html: use "./index.css" — every other page: use "index.css" -->
    <link rel="stylesheet" href="index.css" />
    <title>Report — [Ticket / Topic]</title>
  </head>
  <body class="min-h-screen">
    <!-- nav (only if more than one page) -->
    <!-- header -->
    <!-- content -->
  </body>
</html>
```

## Layout standards for `index.html`

Include these sections when the content supports them — omit a section rather than padding
it with filler:

- **Header** — title, ticket ID, author, date, and a status badge.
- **Executive summary** — a few sentences of business-level context.
- **KPI cards** — a row of `.kpi-card` tiles for headline numbers (e.g. issues found,
  resolved, open, risk count).
- **Key findings** — card layout, one finding per card.
- **Technical details** — implementation or root-cause specifics.
- **Risks** — risk table (description, likelihood, impact, mitigation) when applicable.
- **Recommendations** — concrete action items.
- **Next steps** — checklist or timeline.

## Navigation

When the report has more than one page, include the same `.report-nav` on every page so the
reader never gets stranded, and mark the current page with `class="active"`:

```html
<nav class="report-nav card">
  <a href="index.html" class="active">Overview</a>
  <a href="findings.html">Findings</a>
  <a href="technical-analysis.html">Technical Analysis</a>
</nav>
```

## Tailwind guidelines

Lean on utility classes for layout and spacing; use the shared CSS only for theme variables,
branding, and reusable components. Examples:

```html
<div class="card">…</div>
<div class="grid grid-cols-1 sm:grid-cols-3 gap-4">…</div>
<span class="badge badge--success">Resolved</span>
```

Avoid inventing one-off custom CSS for things a utility class already covers.

## Content rules

The report's value is accuracy, so:

- Present only information the user actually provided. **Do not invent** ticket numbers,
  metrics, dates, names, or findings.
- If something needed for a section is missing, leave a clearly marked placeholder
  (e.g. a muted "TBD — author to confirm") rather than fabricating it, and tell the user
  what's missing.
- Preserve the user's facts and figures exactly; the skill changes presentation, not data.

## Quick checklist before presenting

- [ ] `index.html` and `index.css` exist in a dedicated `./report/[TICKET]/` folder.
- [ ] No styles duplicated across pages; all pages import `index.css`.
- [ ] Brand amber used for accents; dark text on every amber fill (contrast).
- [ ] Status badges follow the semantic color convention.
- [ ] Nav present and correct on every page (if multi-page).
- [ ] Layout responsive at mobile and laptop widths.
- [ ] No fabricated data; gaps flagged.
- [ ] Folder written to `./report/[TICKET]/` and its path presented to the user.
