# Design-time packaging

Place components in a runtime package and registration/editors in a
design-time package that requires it. Keep IDE-only units out of runtime.
Compile the applicable package pair for Win32 and Win64 and install only the
design-time package into the IDE.

Source: Embarcadero RAD Studio package and custom-component documentation.
