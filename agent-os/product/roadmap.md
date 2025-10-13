# Product Roadmap

1. [x] Provider integration & auth — Implement an OpenAI‑compatible provider abstraction, secure API key/config management, and a testable request/response flow so the plugin can call any compatible API. `M`
2. [x] In‑editor generation command — Add a `:VimAIGenerate` command and keybinding to send prompts or selected text to the provider and insert returned text into the buffer; end‑to‑end testable from prompt → insertion. `S` (depends on 1)
3. [x] In‑place edit operation — Add `:VimAIEdit` to send a selection plus an instruction for targeted edits and replace the selection with the model result; includes undoable buffer updates. `S` (depends on 1,2)
4. [x] Interactive chat buffer — Implement a persistent chat buffer UI that maintains context, sends/receives messages, and stores session history for iterative workflows. `M` (depends on 1,2)
5. [x] Provider plugin system & examples — Design a plugin API for third‑party AI providers, implement a plugin loader and an example provider plugin to demonstrate extensibility. `L` (depends on 1)
6. [ ] Creating a new feature with the command :AIAutoComplete which provides text/code suggestions after the user has stopped typing for a couple seconds; the user can then continue typing as usual, or accept the text.

