# Spec Requirements: ai-autocomplete

## Initial Description
AIAutoComplete

## Requirements Discussion

### First Round Questions

**Q1:** I assume `:AIAutoComplete` should trigger suggestions after the user stops typing for ~500–1000ms. Is that timing acceptable, or would you prefer a shorter/longer debounce or manual trigger only?
**Answer:** 1000ms is good; make sure to assign this value to a configurable global configuration variable.

**Q2:** I'm thinking suggestions appear inline as ghost text (accept with `<Tab>` or similar) and also via a popup menu for multiple options. Should we default to ghost text + accept key, or always show a selectable list?
**Answer:** For now keep it simple, only take the first autocompletion result as ghost text.

**Q3:** I assume completions are generated using the current buffer context (±N lines) and the file type for prompt context. Is using the active buffer + filetype correct, or do you want project-wide context or separate session context?
**Answer:** active buffer + filetype is correct.

**Q4:** I'm assuming the feature is opt-in per user and per filetype (configurable allow/deny lists). Should we provide sensible defaults (enabled for code filetypes, disabled for plaintext/large files)?
**Answer:** by default disable this feature using a global configuration variable. Add a filetype whitelist array configuration variable and a filetype blacklist array configuration variable. By default the whitelist is a klein star accepting all filetypes.

**Q5:** I'm thinking suggestions must be quick (median response <300ms for local heuristics, model requests async). Should we surface partial/local suggestions immediately and replace them when model response arrives, or wait for the model response before showing anything?
**Answer:** Only wait for the complete model response.

**Q6:** I assume accepting a suggestion inserts text and preserves undo/redo as a single operation. Is that correct, or do you want granular undo for each inserted chunk?
**Answer:** Yes correct, single operation.

**Q7:** I'm assuming privacy/security: API keys stay local and no telemetry is sent; generated suggestions should not be cached server-side by default. Is that acceptable, or do you want optional cloud sync of presets/usage?
**Answer:** no

**Q8:** Are there any exclusions or special cases we should respect (for example: do not trigger while recording macros, in read-only buffers, in very large files, or for specific project folders)? If so, list them.
**Answer:** yes those special cases should be handled, specifically only include normal buffers for this plugin. Very large files should not be excluded by default. Add a configuration variable to specify the size of a "very large file".

**Extra note provided by user:** this feature uses a naive fill-in-the-middle technique, which simple takes some context above and below the cursor to generate a completion.


### Existing Code to Reference
Based on the repository and product roadmap, these existing areas are likely to contain reusable patterns or implementation examples. (No user-provided paths were given.)

- Provider integration and API wrappers: `py/providers/` and `py/openai.py` (provider code and HTTP handling)
- Completion / request logic: `py/complete.py`, `py/context.py`
- Plugin entrypoints and commands: `plugin/vim-ai.vim`, `autoload/vim_ai.vim`, `autoload/vim_ai_provider.vim`, `autoload/vim_ai_config.vim`
- Config and examples: `roles-default.ini`, `roles-example.ini`, `README.md`

If any of these are incorrect or you prefer different files, please point to exact paths.


## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
No visuals to analyze.


## Requirements Summary

### Functional Requirements
- Add a new `:AIAutoComplete` feature that triggers after a configurable debounce (default 1000ms).
- Generate a single autocompletion result using a fill-in-the-middle technique that takes context above and below the cursor.
- Display the first result as ghost text inline; accepting the suggestion inserts it as a single undoable operation.
- Use active buffer content and filetype as the prompt/context source.
- Provide global opt-in toggle (disabled by default), and filetype `whitelist` and `blacklist` configuration arrays; default whitelist is a glob that accepts all filetypes.
- Respect special cases: only operate on "normal" buffers (not recordings, non-editable buffers), configurable threshold for what constitutes a "very large file" (size in bytes/lines).
- Do not show partial/local suggestions; wait for full model response before displaying ghost text.

### Non-Functional Requirements
- Keep latency reasonable; operations should be asynchronous and not block the editor UI.
- Preserve undo/redo semantics as a single atomic insert.
- API keys and user secrets remain local; no telemetry or server-side caching by default.
- Configurable parameters exposed via existing config system (autoload config module and plugin settings).

### Reusability Opportunities
- Reuse provider abstraction and HTTP client code from `py/providers/` and existing provider implementations.
- Reuse prompt construction and context extraction utilities from `py/context.py` and `py/complete.py`.
- Reuse command/keybinding and config patterns from `plugin/vim-ai.vim` and `autoload/vim_ai_config.vim`.


### Scope Boundaries
**In Scope:**
- Implementing the in-editor auto-complete trigger, model request, ghost-text rendering, accept key behavior, and config options described above.
- Integration with existing provider abstraction and provider plugins.

**Out of Scope:**
- Cloud sync of presets or telemetry collection (explicitly excluded).
- Multi-option popup UI (selectable list) — only single ghost-text result for MVP.
- Aggressive local heuristics or partial suggestion UX — wait for full response only.


### Technical Considerations
- Implement debounce timer with configurable global variable (default 1000ms).
- Implement fill-in-the-middle prompt generation using N lines above and below cursor (configurable context window).
- Ghost text rendering approach: use Neovim virt_text when available; fallback for Vim to compatible inline preview or extmarks if supported.
- Ensure accept-binding inserts text atomically (use buffer API transactions where available).
- Use provider abstraction to call model endpoints; design for async request handling and cancellation when new keystrokes occur before response.
- Add configuration keys:
  - `g:vim_ai_autocomplete_enabled` (default: 0)
  - `g:vim_ai_autocomplete_debounce_ms` (default: 1000)
  - `g:vim_ai_autocomplete_whitelist` (default: ['*'])
  - `g:vim_ai_autocomplete_blacklist` (default: [])
  - `g:vim_ai_autocomplete_large_file_threshold` (default: user-defined size in bytes/lines)
  - `g:vim_ai_autocomplete_context_lines` (default: number of lines above/below cursor)


## Files written
- `agent-os/specs/2025-10-13-ai-autocomplete/planning/requirements.md` (this file)


-------------------------

Requirements research complete!

✅ Processed 8 clarifying questions
✅ Visual check performed: No files found
✅ Reusability opportunities: Identified likely places to reuse existing provider, completion, and config code
✅ Requirements documented comprehensively

Requirements saved to: `agent-os/specs/2025-10-13-ai-autocomplete/planning/requirements.md`

Ready for specification creation.
