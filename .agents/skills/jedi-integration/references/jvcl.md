# JVCL boundary

JVCL requires JCL and is a UI/component dependency. Keep JVCL components out
of the dependency-free core and use separate runtime/design-time packages.
The upstream project states broad Delphi support but does not by itself prove
the user's Delphi 13+ installation; compile validation is mandatory.

Project reference: https://github.com/project-jedi/jvcl
