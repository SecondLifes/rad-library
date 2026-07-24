---
name: "FastReport VCL"
description: "Standards for FastReport VCL reporting — TfrxReport/TfrxDBDataSet wiring, band design, programmatic report generation, exports"
---

# FastReport VCL — Skill

Use this skill for an approved optional **FastReport VCL** integration under
`src/vendor/`. The dependency-free core must not reference FastReport.

> **Commercial dependency:** FastReport VCL is a paid product (an embedded
> edition has shipped with some RAD Studio SKUs — verify what the project's
> license actually includes before using features like specific export
> filters). Do not introduce it as a new dependency without explicit user
> approval. Docs: [fast-report.com — FastReport VCL manuals](https://www.fast-report.com/public_download/docs/FRVCL/online/en/FastReportVCL/UserManual/en-US/Creating_reports/TfrxDBDataSet_component.html).

## Usage

| You say | What happens |
|---|---|
| "Create an invoice/list report for X" | Data wiring (`TfrxDBDataSet` per dataset) + band layout (report title, master data, group header/footer, page footer) + preview/print/export code. |
| "Generate this report fully from code" | Programmatic `TfrxReport` construction (pages, bands, memos) without a designer file — for dynamic layouts. |
| "Export report to PDF/XLSX" | The matching `frxExport*` component wiring and its deployment note. |
| No data source or layout named | Asks which dataset(s) feed the report and what the page structure is — never invents columns. |

## Core wiring

| Component | Role |
|---|---|
| `TfrxReport` | The report itself — loads/saves `.fr3`, `PrepareReport`, `ShowReport`, `Print` |
| `TfrxDBDataSet` | Bridge: one per Delphi dataset the report may read (`DataSet` property → your `TFDQuery` etc.) |
| `TfrxPDFExport` / `TfrxXLSXExport` / ... | Export filters, one per target format |
| `TfrxDesigner` | Embeds the end-user designer (only if end-user editing is a real requirement) |

Verified against the vendor manual: a dataset participates in a report
only after its `TfrxDBDataSet` is enabled for the report (designer:
Report → Data...; code: add to `Report.DataSets`).

```pascal
//Raporu hazırlayıp önizleme
frxDBCustomers.DataSet := qryCustomers;    //köprü
frxReport.LoadFromFile(ReportPath('customer-list.fr3'));
if frxReport.PrepareReport then
  frxReport.ShowReport;                    //modal önizleme

//PDF'e sessiz export
frxPDFExport.FileName := LOutputPath;
frxPDFExport.ShowDialog := False;
if frxReport.PrepareReport then
  frxReport.Export(frxPDFExport);
```

## Conventions

- **Templates as files, not resources, during development** — `.fr3`
  files under a `reports/` folder, path resolved by a single helper;
  embed as resources only for deployment if the project requires it.
- **Data shaping belongs in SQL/datasets, not report script.** The
  report lays out data; filtering/aggregation happens in the query.
  FastReport's script engine is for presentation logic only (visibility
  toggles, formatting) — business rules in report script are unfindable
  and untestable.
- **Master data band ↔ dataset binding** is per band; group bands need
  the dataset ordered by the group expression (ORDER BY in SQL — the
  report doesn't sort for you).
- **Variables/parameters** passed from code via
  `frxReport.Variables['VarName']` — quote string values
  (`QuotedStr`) because variable values are expressions.
- **Threading:** prepare/export on the main thread unless the project
  has verified its FastReport version's threading support — UI preview
  is main-thread-only regardless.
- **Naming prefixes:** `frx` for report components (`frxReport`,
  `frxDBCustomers`, `frxPDFExport`).

## Checklist

- [ ] One `TfrxDBDataSet` per participating dataset, all enabled in the report?
- [ ] Queries ordered to match group bands?
- [ ] No business logic in report script?
- [ ] Export filters deployed/licensed for the formats actually offered?
- [ ] Report templates versioned in the repo alongside code?
