# `src/` layout contract

This directory is intentionally documentation-only at kit creation. The user
decides real modules and APIs while coding.

```text
src/
├── core/        dependency-free reusable library code
├── helpers/     help.* units; public helper functions/methods begin with _
├── components/
│   ├── vcl/     VCL runtime/design-time package pairs
│   └── fmx/     FMX runtime/design-time package pairs
├── test/        DUnitX projects and *.test.pas units
└── vendor/      optional, isolated vendor adapters/packages/tests
```

All project-related paths remain under `src/`. A source named
`help.date.pas` is tested by `src/test/.../help.date.test.pas`. Component
classes use `TRAD`. No example name defines behavior or authorizes the AI to
invent a public API.
