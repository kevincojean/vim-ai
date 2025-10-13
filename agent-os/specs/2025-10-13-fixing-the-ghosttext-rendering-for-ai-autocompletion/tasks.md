# Task Breakdown: Fixing the Ghosttext Rendering for AI Autocompletion

## Overview
Total Tasks: 8
Assigned roles: testing-engineer, ui-designer

## Task List

### Regression Harness

#### Task Group 1: Failure Reproduction & Guardrails
**Assigned implementer:** testing-engineer
**Dependencies:** None

- [ ] 1.0 Build cross-runtime regression coverage
  - [ ] 1.1 Add failing Neovim ghost text regression tests in `tests/autocomplete_test.py` that exercise streaming updates and cleanup using the diagnostics virtual text path.
  - [ ] 1.2 Extend `tests/mocks/vim.py` and related fixtures to emulate Vim 9 text properties for ghost text overlays and assert current breakages.
  - [ ] 1.3 Capture cleanup regressions by writing tests that move between buffers/modes and verify overlays clear.
  - [ ] 1.4 Run ONLY the tests written above (expect failures) and document failure signatures to hand off to implementer.

**Acceptance Criteria:**
- Regression tests cover Neovim virtual text and Vim text property flows.
- Tests fail against current implementation, documenting failures for downstream fix work.
- Cleanup scenarios (buffer switch, mode change, accept/dismiss) are represented.
- Execution instructions limit scope to the newly added regression tests.

### Rendering Alignment

#### Task Group 2: Ghost Text Rendering Fix Implementation
**Assigned implementer:** ui-designer
**Dependencies:** Task Group 1

- [ ] 2.0 Align ghost text overlay with diagnostics pipeline
  - [ ] 2.1 Refactor `autoload/vim_ai_autocomplete.vim` (and helpers) to route streamed suggestions through the diagnostics virtual text implementation for Neovim and text properties for Vim, without mutating buffer text.
  - [ ] 2.2 Introduce per-buffer ghost text state and autocommands ensuring overlays update on streaming chunks and clear on cursor move, mode change, or buffer switch.
  - [ ] 2.3 Harmonize highlight groups, placement offsets, and cleanup routines with existing diagnostics utilities so overlays appear inline and never linger.
  - [ ] 2.4 Update `doc/vim-ai.txt` (and related README sections if needed) with configuration flags, compatibility notes, and troubleshooting guidance for the restored ghost text feature.
  - [ ] 2.5 Run ONLY the regression tests from Task Group 1 to confirm they now pass with the fix applied.

**Acceptance Criteria:**
- Ghost text renders via diagnostics virtual text on Neovim and text properties on Vim 9+ without modifying buffers.
- Streaming updates, accept/dismiss actions, and buffer/mode transitions leave no orphan state.
- Documentation reflects configuration, version support, and cleanup semantics.
- Regression tests from Task Group 1 pass.

## Execution Order
1. Task Group 1: Failure Reproduction & Guardrails (testing-engineer)
2. Task Group 2: Ghost Text Rendering Fix Implementation (ui-designer)
