# Rendering, styles and platforms

Separate model/state from presentation. Prefer FMX style resources and
framework services over platform-specific assumptions. Guard Windows-only
code explicitly and keep it outside the portable core. UI access is
main-thread-only; marshal worker results before touching controls.
