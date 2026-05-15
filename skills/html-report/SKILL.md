---
name: html-report
description: >
  Generate polished, modern dark-themed HTML documents and reports using Tailwind CSS and Chart.js
  for end-user consumption. Use this skill whenever the user asks you to create a report, plan,
  document, summary, analysis, proposal, or any content intended for human reading — especially
  when they want something presentable, shareable, or printable. Triggers on: "generate report",
  "create document", "write up", "make a page", "html report", "prepare document for",
  "present findings", "create a summary page", "write documentation for [audience]", or any
  request where the output is a document meant for people to read (not code to execute).
  Also use when user explicitly asks for HTML output or mentions html-report.
---

# HTML Report Generator

Generate modern, dark-themed, self-contained HTML documents using Tailwind CSS and Chart.js.
Every report lives in its own dated folder under `./html-report/` and is ready to open in a browser.

## Output Structure

```
./html-report/
  └── YYYY-MM-DD-SCOPE-short-summary/
      ├── index.html          (always present — entry point)
      ├── details.html        (optional — breakdowns, deep dives)
      ├── appendix.html       (optional — raw data, references)
      └── assets/             (optional — images, diagrams if needed)
```

## Folder Naming

Format: `YYYY-MM-DD-SCOPE-short-summary`

- **Date**: today's date (YYYY-MM-DD)
- **Scope**: 2-4 char tag for domain (FE, BE, DB, API, INFRA, OPS, PLAN, etc.)
- **Summary**: 2-5 words, kebab-case, describing content

Examples:
- `2026-05-11-FE-refactor-checkout-flow`
- `2026-05-11-API-auth-migration-plan`
- `2026-05-11-PLAN-q3-roadmap-proposal`
- `2026-05-11-DB-schema-audit-results`

If scope unclear, use `GEN` (general).

## CDN Dependencies

Always include both in `<head>`:

```html
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
```

## HTML Template

Every HTML file follows this base structure. The design language is dark, minimal, and modern —
think Linear, Vercel dashboard, or Raycast. Rounded corners, subtle borders, glass-like cards.

```html
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>[Report Title]</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          colors: {
            surface: {
              DEFAULT: '#0a0a0a',
              50: '#111111',
              100: '#1a1a1a',
              200: '#262626',
              300: '#333333',
            },
            accent: {
              DEFAULT: '#6366f1',
              light: '#818cf8',
              dim: '#4f46e5',
            }
          }
        }
      }
    }
  </script>
  <style type="text/tailwindcss">
    @layer base {
      body {
        @apply bg-surface text-gray-200 antialiased font-sans;
        font-family: 'Inter', system-ui, -apple-system, sans-serif;
      }
      h1 { @apply text-3xl font-bold text-white mb-2 tracking-tight; }
      h2 { @apply text-xl font-semibold text-gray-100 mt-10 mb-4; }
      h3 { @apply text-lg font-medium text-gray-200 mt-6 mb-2; }
      p { @apply text-sm leading-relaxed text-gray-400 mb-4; }
      ul, ol { @apply mb-4 pl-5 text-sm text-gray-400; }
      li { @apply mb-1.5; }

      /* Tables */
      table { @apply w-full mb-6 text-sm; }
      thead { @apply border-b border-surface-300; }
      th { @apply text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider; }
      td { @apply px-4 py-3 text-gray-300 border-b border-surface-200; }
      tr:hover td { @apply bg-surface-100; }

      /* Code */
      code { @apply bg-surface-200 text-indigo-300 text-xs px-1.5 py-0.5 rounded font-mono; }
      pre { @apply bg-surface-100 border border-surface-200 text-gray-300 p-4 rounded-xl overflow-x-auto mb-6 text-xs; }
      pre code { @apply bg-transparent text-gray-300 px-0 py-0; }

      a { @apply text-accent-light hover:text-white transition-colors duration-150; }
    }
  </style>
</head>
<body>
  <div class="max-w-5xl mx-auto px-8 py-16">

    <!-- Navigation (if multi-page) -->
    <nav class="mb-10 flex items-center gap-1 text-sm">
      <a href="index.html"
         class="px-3 py-1.5 rounded-lg bg-surface-100 text-gray-300 hover:text-white hover:bg-surface-200 transition-all">
        Overview
      </a>
      <!-- Add links to other pages as needed -->
    </nav>

    <!-- Header -->
    <header class="mb-12">
      <p class="text-xs font-medium text-accent uppercase tracking-widest mb-3">Report</p>
      <h1>[Title]</h1>
      <p class="text-gray-500 text-sm mt-1">[date] · [scope/context]</p>
    </header>

    <!-- Content -->
    <main>
      <!-- Report body here -->
    </main>

    <!-- Footer -->
    <footer class="mt-20 pt-6 border-t border-surface-200 text-xs text-gray-600">
      Generated on [date]
    </footer>
  </div>
</body>
</html>
```

## Design System

### Cards
Glass-like containers with subtle borders. Primary building block.

```html
<div class="bg-surface-100 border border-surface-200 rounded-xl p-6 mb-4">
  <h3 class="text-white font-semibold mb-2">Section Title</h3>
  <p class="text-gray-400 text-sm">Content here</p>
</div>
```

### Stat Cards
For KPIs, metrics, counts. Use a row of these at top of report.

```html
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div class="bg-surface-100 border border-surface-200 rounded-xl p-5">
    <p class="text-xs text-gray-500 uppercase tracking-wider mb-1">Total Items</p>
    <p class="text-2xl font-bold text-white">42</p>
    <p class="text-xs text-emerald-400 mt-1">+12% from last sprint</p>
  </div>
</div>
```

### Status Badges
Pill-shaped, muted backgrounds matching dark theme.

```html
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-400 ring-1 ring-emerald-500/20">Complete</span>
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-amber-500/10 text-amber-400 ring-1 ring-amber-500/20">In Progress</span>
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-red-500/10 text-red-400 ring-1 ring-red-500/20">Blocked</span>
<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 ring-1 ring-indigo-500/20">Info</span>
```

### Priority Indicators
Use colored dots + text.

```html
<span class="flex items-center gap-1.5 text-xs">
  <span class="w-2 h-2 rounded-full bg-red-400"></span>
  <span class="text-gray-300">High</span>
</span>
```

### Callout / Alert Boxes
Accent border on left, translucent background.

```html
<div class="bg-indigo-500/5 border-l-2 border-indigo-500 rounded-r-lg px-4 py-3 mb-6">
  <p class="font-medium text-indigo-300 text-sm">Key Insight</p>
  <p class="text-gray-400 text-xs mt-1">Supporting detail here.</p>
</div>

<div class="bg-amber-500/5 border-l-2 border-amber-500 rounded-r-lg px-4 py-3 mb-6">
  <p class="font-medium text-amber-300 text-sm">Warning</p>
  <p class="text-gray-400 text-xs mt-1">Something needs attention.</p>
</div>
```

### Section Dividers
Subtle horizontal rules between major sections.

```html
<div class="border-t border-surface-200 my-10"></div>
```

## Charts with Chart.js

Use Chart.js for data visualization. Charts make reports feel alive — include them whenever
there's quantitative data that benefits from visual representation.

**When to use charts:**
- Progress over time → line chart
- Distribution / breakdown → doughnut or pie chart
- Comparison between items → horizontal bar chart
- Before/after or target vs actual → bar chart
- Timeline / milestones → can use a horizontal bar as gantt-like

**Chart styling for dark theme:**

```html
<div class="bg-surface-100 border border-surface-200 rounded-xl p-6 mb-6">
  <h3 class="text-white font-semibold mb-4">Chart Title</h3>
  <div class="relative" style="height: 280px;">
    <canvas id="myChart"></canvas>
  </div>
</div>

<script>
new Chart(document.getElementById('myChart'), {
  type: 'doughnut',
  data: {
    labels: ['Complete', 'In Progress', 'Not Started'],
    datasets: [{
      data: [5, 7, 3],
      backgroundColor: ['#34d399', '#fbbf24', '#6b7280'],
      borderColor: '#1a1a1a',
      borderWidth: 3,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: { color: '#9ca3af', padding: 16, usePointStyle: true, pointStyleWidth: 8 }
      }
    }
  }
});
</script>
```

**Chart color palette (dark-theme friendly):**
- Emerald: `#34d399` — success, complete
- Amber: `#fbbf24` — warning, in-progress
- Indigo: `#818cf8` — primary accent
- Rose: `#fb7185` — critical, error
- Gray: `#6b7280` — neutral, not started
- Cyan: `#22d3ee` — info, secondary
- Violet: `#a78bfa` — tertiary

**Chart.js dark theme defaults:**
- Always set `borderColor: '#1a1a1a'` on datasets (matches surface bg)
- Grid lines: `color: '#262626'`
- Tick labels: `color: '#9ca3af'`
- Set `maintainAspectRatio: false` and wrap canvas in a div with explicit height

**Include at least one chart per report** when there's quantitative data. For purely narrative
reports with no numbers, charts are optional.

## Design Principles

1. **Dark & modern.** Think Linear/Vercel aesthetic. `#0a0a0a` base, subtle borders at `#262626`,
   white text for headings, `gray-400` for body text. No pure white backgrounds anywhere.

2. **Generous spacing.** Let content breathe. `py-16` page padding, `mb-8` between sections,
   `gap-4` in grids. Dense information should still feel airy.

3. **Subtle depth.** Use `border border-surface-200` instead of shadows. Occasional
   `ring-1 ring-inset` on interactive-looking elements. No heavy drop shadows.

4. **Color with restraint.** Most UI is grayscale. Color appears only for:
   - Status indicators (emerald/amber/red)
   - Accent elements (indigo)
   - Chart data
   - Links

5. **Typography hierarchy.** White for headings, `gray-200` for subheadings, `gray-400` for body,
   `gray-500` for metadata/timestamps, `gray-600` for footer.

6. **Rounded everything.** `rounded-xl` on cards, `rounded-lg` on nav items, `rounded-full` on
   badges. No sharp corners.

## When to Split Into Multiple Pages

- **Single page** (just index.html): content fits comfortably, < ~50 sections
- **Multi-page**: content has distinct logical sections that benefit from separation
  - index.html = overview / executive summary with links to detail pages
  - Each detail page = deep dive on one topic
  - Every page includes consistent nav linking to all pages

## Content Guidelines

- Write for the intended audience. Adjust language for stakeholders vs engineers.
- Lead with conclusion or recommendation, then supporting details.
- Use tables for comparisons, timelines, structured data.
- Include TL;DR or executive summary at top for longer reports.
- Number sections if report has > 5 major sections.
- If report covers issues/risks, always include severity and recommended action.

## Workflow

1. Understand what user wants documented and who will read it
2. Create folder: `./html-report/YYYY-MM-DD-SCOPE-summary/`
3. Write index.html (always first)
4. Add additional pages if content warrants splitting
5. Tell user path and suggest: `open ./html-report/YYYY-MM-DD-SCOPE-summary/index.html`

## Anti-patterns

- Don't use JavaScript frameworks. Plain HTML + Tailwind + Chart.js only.
- Don't add interactive features (dropdowns, modals, toggles) unless user specifically asks.
- Don't create empty placeholder pages. Every file must have real content.
- Don't put CSS in separate files — keep everything inline via Tailwind CDN for self-containment.
- Don't use light/white backgrounds. Everything stays dark.
- Don't over-chart. One chart that tells a story beats five that clutter.
