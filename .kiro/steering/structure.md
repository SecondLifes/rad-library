# Structure — RAD Library

```text
src/
├── core/
├── helpers/
├── components/
│   ├── vcl/
│   └── fmx/
├── test/
└── vendor/
```

The kit creates no project source. The user decides modules and APIs while
coding. Helper filenames begin with `help.`; test filenames append `.test`;
all project-related directories remain under `src/`.
