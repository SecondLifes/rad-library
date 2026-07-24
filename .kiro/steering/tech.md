# Technical Stack — RAD Library

- Object Pascal, Delphi 13+ (current stable reference)
- dcc32/dcc64 and MSBuild where available
- Win32/Win64, VCL/FMX
- DUnitX
- SemVer, initial kit version `0.1.0`

Correctness precedes performance. Performance claims require Release
Win32/Win64 baselines, allocation evidence, warm-up, repetition and outlier
treatment. Core/helpers avoid UI dependencies, mutable globals and mandatory
logging. UI access is main-thread-only.
