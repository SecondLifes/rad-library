# Component lifecycle and streaming

Use FMX ownership and notification deliberately. Keep constructor defaults,
published properties and streamed values aligned. Defer side effects while
loading and avoid design-time network, database or filesystem work. Verify a
save/load round trip for published state.

Authoritative basis: Embarcadero RAD Studio documentation for creating FMX
components and component streaming. Re-check the current Delphi release
documentation before version-sensitive implementation.
