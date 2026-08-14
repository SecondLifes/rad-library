# Vendor Integration

## Two tiers, not one

**mORMot2 is a base dependency, not an optional vendor.** `src/core/` uses it
directly — serialization, RTTI, crypto and the OS primitives the core is built
on all come from it. There is no dependency-free build of this library and
there is not meant to be one. Calling mORMot from a core unit needs no adapter,
no conditional compilation and no justification.

**Every other vendor is optional and isolated.** UniDAC, DevExpress, TMS,
FastReport and JEDI JCL/JVCL are feature-scoped integrations that live under
`src/vendor/`.

> **Corrected claim.** This file, `library-packaging.md`, `AGENTS.md`, the four
> identity files and five skills all used to say "the core is dependency-free."
> That was never true of shipped code — `rad.core`, `rad.cipher`, `rad.config`,
> `rad.cache`, `rad.utils`, `rad.thread` and `rad.eventbus` all `uses` mORMot —
> and it was actively harmful: a rule that contradicts the code teaches the
> next session either to break working code enforcing it, or to ignore the
> rules generally. The isolation requirement was always about the *other*
> vendors; only the wording was wrong.

## Rules for optional vendors

- Never make an optional vendor package a transitive dependency of the core.
- Keep vendor runtime/design-time packages separate where components are
  installed into the IDE.
- Preserve vendor exception causes and document thread-safety limits.
- Do not redistribute proprietary source, binaries, credentials or license
  material.
- Run vendor tests separately and state the exact installed version and
  compiler used.
- JEDI remains conditional until compiled with Delphi 13+ on the user's
  machine. Documentation compatibility is not runtime verification.

## Rules for mORMot2

Being a base dependency buys directness, not trust. The same verification
discipline applies, and more sharply, because a core unit's bug reaches
everything above it:

- Pin or record the exact revision; never rely on an unqualified "latest".
- Read `.agents/skills/mormot2-integration/references/verified-api-traps.md`
  before using an unfamiliar API, and add to it whenever a probe uncovers
  another trap. Several mORMot APIs compile cleanly and fail silently — one
  of them would have shipped a documented tamper-detection guarantee that the
  code did not provide.
- `mormot.crypt.*` additionally needs the separately-downloaded `static/`
  binaries; see that same reference.
