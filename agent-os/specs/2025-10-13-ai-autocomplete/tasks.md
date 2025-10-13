# Task Breakdown: AIAutoComplete

## Overview
Total Tasks: 14
Assigned roles: api-engineer, ui-designer

## Task List

### Autocomplete Engine & Config

#### Task Group 1: Core Autocomplete Pipeline
**Assigned implementer:** api-engineer
**Dependencies:** None

- [x] 1.0 Establish configuration and debounce foundation
  - [x] 1.1 Write config values, debounce timing, whitelist/blacklist evaluation, and large-file threshold handling (use existing mock provider/context helpers).
  - [x] 1.2 Define new config globals in `autoload/vim_ai_config.vim` (enable toggle, debounce, whitelist/blacklist, large-file threshold, context lines) with documentation comments.
  - [x] 1.3 Implement event hooks to start/reset the debounce timer after Normal mode insertions and cursor moves; ensure only "normal" buffers trigger requests.
  - [x] 1.4 Reuse `py/context.py` to gather fill-in-the-middle context (configurable lines above/below cursor) and prepare provider payload; wire through existing provider abstraction to request a single completion.
  - [x] 1.5 Ensure only the tests written in 1.1 pass (run targeted pytest module or functions); do not run the full suite.

**Acceptance Criteria:**
- Config variables load with documented defaults and are user-overridable.
- Debounce timer waits 1000ms by default and respects config override.
- Requests only fire for normal buffers respecting whitelist/blacklist and large-file guard.
- Context payload uses active buffer/filetype with fill-in-the-middle markers.
- Tests from 1.1 pass.

### Rendering & UX

#### Task Group 2: Ghost Text Display & Interactions
**Assigned implementer:** ui-designer
**Dependencies:** Task Group 1

- [x] 2.0 Implement inline suggestion UX
  - [x] 2.1 Implement ghost-text rendering in Vim; it is possible, LSP plugins using virtual text manage to do it.; ensure cleanup when focus or buffer changes.
  - [x] 2.2 Add accept binding (default `<Tab>`), manual dismiss shortcut, and cancellation when user resumes typing before response arrives.
  - [x] 2.3 Update `doc/vim-ai.txt` and/or README with configuration keys, usage instructions, and known limitations for ghost-text mode.

**Acceptance Criteria:**
- Ghost text displays only after full model response and clears correctly on insert/motion changes.
- Accepting suggestion inserts text in one undo step; dismissal leaves buffer unchanged.
- UX respects buffer scope, whitelist/blacklist, and cancellation behavior.
- Documentation covers enabling, configuring, accepting, and dismissing suggestions.


## Execution Order
Recommended implementation sequence:
1. Task Group 1: Core Autocomplete Pipeline (api-engineer)
2. Task Group 2: Ghost Text Display & Interactions (ui-designer)
