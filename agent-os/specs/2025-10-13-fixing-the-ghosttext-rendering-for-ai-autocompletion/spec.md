# Specification: Fixing the ghosttext rendering for AI Autocompletion

## Goal
- Restore a reliable ghost text experience for Vim AI autocompletion by aligning with the existing diagnostics virtual text pipeline while ensuring suggestions display inline without mutating the buffer.
- Deliver a configurable, low-latency overlay that works across Neovim and Vim 9 environments and survives real-time typing.

## User Stories
- As a Vim user, I want ghost text to appear inline as a non-intrusive preview so I can decide whether to accept or ignore AI suggestions without altering the buffer.
- As a maintainer, I want the overlay to reuse the proven diagnostics virtual text pipeline so the fix ships faster and remains supportable.

## Core Requirements
### Functional Requirements
- Render AI suggestion ghost text via virtual text or text properties without changing buffer contents.
- Update ghost text as completions stream, respecting cursor movement, buffer boundaries, and insert mode toggles.
- Ensure cleanup of ghost text when completions retract, buffers change, or insert mode rules demand clearing.

### Non-Functional Requirements
- Maintain compatibility with Neovim ≥0.3 (virtual text) and Vim ≥9.0.0178 (text properties).

## Reusable Components

## Technical Specification
### Overview
- **Support Matrix:** Neovim ≥0.3 renders ghost text via `nvim_buf_set_virtual_text`; Vim ≥9.0.0178 uses text properties (`prop_add`) to emulate inline overlays.

## Success Criteria
- Ghost text renders reliably for AI suggestions in Neovim ≥0.3 and Vim ≥9.0.0178 without modifying buffers.

## Important Constraints
1. Always search for reusable code before creating new components.
2. Reference visual assets when available.
3. Do not write actual code in the spec.
4. Keep each section short and skimmable.
5. Document why new code is needed if reuse is not possible.

## Display confirmation and next step
```
The spec has been created at `agent-os/specs/2025-10-13-fixing-the-ghosttext-rendering-for-ai-autocompletion/spec.md`.

Review it closely to ensure everything aligns with your vision and requirements.

Next step: Run the command, 2-create-tasks-list.md
```

## User Standards & Preferences Compliance
- Align with the project standards and conventions listed in:
  @agent-os/standards/global/coding-style.md
  @agent-os/standards/global/commenting.md
  @agent-os/standards/global/conventions.md
  @agent-os/standards/global/error-handling.md
  @agent-os/standards/global/tech-stack.md
  @agent-os/standards/global/validation.md
