# Tech Stack for Vim AI Plugin

## User-provided constraint
- This is a Vim/Neovim plugin. The user's preference to keep this as a plugin takes precedence.

## Languages & Runtimes
- **Vimscript (vimL):** Core compatibility across Vim and Neovim (plugin entrypoints, autoload functions).
- **Python 3:** Provider implementations, API wrappers, tests, and optional provider plugins (folder: `py/`).

## Package & Dependency Management
- **Python:** `pip` and virtualenv for developer environment and provider plugin installation.
- **Vim/Neovim plugin managers:** Support installation via `vim-plug`, `packer.nvim`, and native package layout.

## Provider & API
- **OpenAI-compatible APIs:** HTTP-based API clients implemented in Python (provider abstraction to support alternative providers).
- **HTTP client:** Python's standard `requests` (implementation choice left to maintainers; keep dependencies minimal).

## Testing & Quality
- **Test framework:** `pytest` for Python unit/integration tests (project already includes tests/ with pytest config).
- **Linting/Formatting:** Follow project standards; Python tools such as `ruff`/`black` or `flake8` are acceptable (align with `agent-os/standards/global/coding-style.md`).

## Documentation & Examples
- **Docs format:** Markdown (`README.md`, `agent-os/product/*`) with usage examples and role/preset samples.
- **Examples:** Example workflows and minimal config snippets for common plugin managers.

## Notes
- Choices above are reconciled with the user's instruction that this is simply a Vim plugin and the repository's existing layout (Vimscript + `py/` provider code and pytest-based tests).
- Keep external dependencies minimal and optional; prefer shippable plugin that works out-of-the-box for users with standard Vim/Neovim setups.
