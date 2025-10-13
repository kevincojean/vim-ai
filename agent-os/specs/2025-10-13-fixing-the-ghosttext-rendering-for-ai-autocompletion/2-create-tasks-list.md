# Tasks for Spec: Fixing the ghosttext rendering for AI Autocompletion

1. **Reproduce Failure Modes**: Capture ghost text rendering issues across Neovim ≥0.3 and Vim ≥9.0.0178 with streaming autocomplete suggestions.
2. **Implementation – Placement & Cleanup**: Ensure streamed suggestions convert to ghost text/text properties with correct highlights and per-buffer cleanup.
