# Specification: AIAutoComplete

## Goal
Provide an editor-native AI-powered inline autocompletion feature that generates a single, context-aware completion using a fill-in-the-middle approach and displays it as ghost text for the user to accept or ignore.

## User Stories
- As a Vim/Neovim user, I want AI suggestions appear inline after I pause typing so I can accept them quickly and continue editing without context switching.
- As a power user, I want the feature disabled by default and opt-in per my config so it doesn't change my editor experience unexpectedly.
- As a contributor, I want the implementation to reuse existing provider and prompt utilities so the feature integrates with current provider plugins.

## Core Requirements
### Functional Requirements
- Trigger: Start a debounce timer after user input; default debounce = `1000ms`, configurable via `g:vim_ai_autocomplete_debounce_ms`.
- Generation: When timer fires, gather context using the active buffer and filetype, take N lines above and below cursor (`g:vim_ai_autocomplete_context_lines`), and generate a single completion using a naive fill-in-the-middle technique.
- Display: Render the first completion as ghost text inline (Neovim: `virt_text`; Vim: best-effort fallback). Do not show partial or interim suggestions — wait for the complete model response.
- Accept: Accepting the suggestion inserts the completion atomically as a single undoable operation; default accept keybinding configurable (e.g., `<Tab>`).
- Enablement & Scope: Feature disabled by default (`g:vim_ai_autocomplete_enabled = 0`). Provide `g:vim_ai_autocomplete_whitelist` (default `['*']`) and `g:vim_ai_autocomplete_blacklist` (default `[]`) to control filetypes. Only run in "normal" buffers (not recording, not read-only, not special/builtin buffers). Add `g:vim_ai_autocomplete_large_file_threshold` to define a "very large file" size; large files are not excluded by default but can be guarded by this threshold.
- Cancellation: If further typing occurs before a response arrives, cancel the pending request and reset the debounce timer.
- Provider: Use existing provider abstraction to send requests; support async/non-blocking calls and safe cancellation.

### Non-Functional Requirements
- Latency: Asynchronous requests must not block the editor UI; display only after full response.
- Reliability: Insert operations must preserve undo/redo semantics as a single atomic action.
- Security & Privacy: Do not send telemetry or cache suggestions server-side by default; API keys remain local and use existing provider configuration patterns.
- Configurability: All user-visible behaviors are controlled via global config variables documented in the plugin's config interface.

## Visual Design
No mockups provided.
- Display is inline ghost text; no popup or multi-option UI for MVP.

## Reusable Components
### Existing Code to Leverage
- Provider abstraction and HTTP clients: `py/providers/`, `py/openai.py` (use these for model calls and auth handling).
- Prompt/context utilities: `py/context.py`, `py/complete.py` (reuse context extraction and prompt building where appropriate).
- Plugin entrypoints and config patterns: `plugin/vim-ai.vim`, `autoload/vim_ai_config.vim`, `autoload/vim_ai.vim` (follow existing command and option conventions).

### New Components Required
- `autoload/vim_ai_autocomplete.vim` (or Lua equivalent) to manage debounce, context collection, display, and accept behavior.
- Async request manager for autocomplete flows (may live in `py/` provider helpers or integrated with existing async request patterns) to handle cancellation and responses.
- Ghost-text rendering adapter that uses Neovim `virt_text` when available and a compatible fallback for Vim.

Document why new code is needed: existing code provides provider and prompt utilities but not an editor-side debounce/ghost-text pipeline, atomic accept handling, or the specific fill-in-the-middle prompt strategy.

## Technical Approach
- Debounce: Implement a 1000ms default debounce timer in the editor layer (Vimscript). Expose config `g:vim_ai_autocomplete_debounce_ms`.
- Context Extraction: Use existing `py/context.py` patterns to extract N lines above/below cursor; default configurable via `g:vim_ai_autocomplete_context_lines`.
- Prompt Strategy: Construct a fill-in-the-middle prompt that sends context above and below the cursor with a marker for insertion point; keep prompt size bounded to avoid large requests.
- Async Requests: Use provider abstraction to send async requests; ensure requests are cancellable when new keystrokes occur.
- Rendering: Use Neovim `nvim_buf_set_extmark`/`virt_text` for ghost text; for Vim, use available preview or echo fallback and document limitations.
- Accept Operation: When user accepts, perform an atomic buffer edit (transaction) so the entire insertion is a single undo step.
- Config: Add documented global config variables with clear defaults and instructions for per-user overrides.

## Out of Scope
- Multi-option popup menu or selection UI (deferred to future feature).
- Partial or streaming suggestion UI — the feature waits for the full model response.
- Cloud sync, telemetry, or server-side caching of suggestions.

## Success Criteria
- Functionally, users can enable `:AIAutoComplete`, pause typing for ~1000ms, see a single ghost-text completion generated from buffer context, and accept it with one keypress producing a single undo entry.
- Performance: Autocomplete requests and rendering do not block typing; cancelation on new input occurs correctly.
- Reliability: Integration tests with a mock provider pass for generation, cancellation, and accept flow.
- Developer ergonomics: Implementation reuses provider and prompt utilities; new code is focused and documented.
