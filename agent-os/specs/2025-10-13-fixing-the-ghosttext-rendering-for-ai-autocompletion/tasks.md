# Task Breakdown: Fixing the Ghosttext Rendering for AI Autocompletion

## Overview
Total Tasks: 8
Assigned roles: testing-engineer, ui-designer

## Task List

### Regression Harness

#### Task Group 1: Ghost Text Rendering Fix Implementation
**Assigned implementer:** ui-designer
**Dependencies:** Task Group 1

- [ ] 1.0 Align ghost text overlay with diagnostics pipeline
  - [ ] 1.1 Refactor `autoload/vim_ai_autocomplete.vim` (and helpers) to route streamed suggestions through the diagnostics virtual text implementation for Neovim and text properties for Vim, without mutating buffer text.
  - [ ] 1.2 Introduce per-buffer ghost text state and autocommands ensuring overlays update on streaming chunks and clear on cursor move, mode change, or buffer switch.
  - [ ] 1.3 Harmonize highlight groups, placement offsets, and cleanup routines with existing diagnostics utilities so overlays appear inline and never linger.
  - [ ] 1.4 Update `doc/vim-ai.txt` (and related README sections if needed) with configuration flags, compatibility notes, and troubleshooting guidance for the restored ghost text feature.

**Acceptance Criteria:**
- Ghost text renders via diagnostics virtual text on Neovim and text properties on Vim 9+ without modifying buffers.
- Streaming updates, accept/dismiss actions, and buffer/mode transitions leave no orphan state.
- Documentation reflects configuration, version support, and cleanup semantics.

## Execution Order
1. Task Group 1: Ghost Text Rendering Fix Implementation (ui-designer)
