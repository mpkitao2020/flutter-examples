# Release gate artifacts

Put production release gate evidence files in this directory before closing
`docs/evidence/release_gates.manifest.json`.

The manifest verifier only accepts evidence paths under
`docs/evidence/artifacts/`. Do not point evidence at runbooks, plans, specs, or
other markdown-only process documents.

Artifact files are ignored by git by default. Keep this README committed so the
directory and rules are visible.
