import vim
import fnmatch
import traceback
from copy import deepcopy

from context import make_ai_context
from utils import (
    update_thread_shared_variables,
    make_config,
    parse_chat_messages,
    load_provider,
    ai_provider_utils,
    handle_completion_error,
    KnownError,
    clear_echo_message,
    print_debug,
)

autocomplete_py_imported = True

FIM_PREFIX = "<fim_prefix>"
FIM_MIDDLE = "<fim_middle>"
FIM_SUFFIX = "<fim_suffix>"


def _eval(expr, default=None):
    try:
        return vim.eval(expr)
    except Exception:
        return default


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    if isinstance(value, (int, float)):
        return value != 0
    value_str = str(value)
    return value_str not in ("", "0")


def _as_int(value, default=0):
    try:
        if isinstance(value, str) and value == "":
            return default
        return int(value)
    except (TypeError, ValueError):
        return default


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if value == "":
        return []
    return [value]


def _load_complete_base_config():
    base_config = deepcopy(_eval("g:vim_ai_complete", {}))
    if isinstance(base_config, dict) and base_config.get("provider"):
        return base_config

    try:
        vim.command("call vim_ai_config#load()")
    except vim.error:
        pass

    base_config = deepcopy(_eval("g:vim_ai_complete", {}))
    if isinstance(base_config, dict) and base_config.get("provider"):
        return base_config

    fallback_config = deepcopy(_eval("g:vim_ai_complete_default", {}))
    if isinstance(fallback_config, dict) and fallback_config:
        return fallback_config

    return base_config if isinstance(base_config, dict) else {}


def get_runtime_config():
    return {
        "enabled": _as_bool(_eval("g:vim_ai_autocomplete_enabled", 0)),
        "debounce_ms": _as_int(_eval("g:vim_ai_autocomplete_debounce_ms", 1000), 1000),
        "whitelist": _as_list(_eval("g:vim_ai_autocomplete_whitelist", [])),
        "blacklist": _as_list(_eval("g:vim_ai_autocomplete_blacklist", [])),
        "large_file_threshold": _as_int(_eval("g:vim_ai_autocomplete_large_file_threshold", 0), 0),
        "context_lines": _as_int(_eval("g:vim_ai_autocomplete_context_lines", 20), 20),
        "model": _eval("g:vim_ai_autocomplete_model", ""),
        "provider": _eval("g:vim_ai_autocomplete_provider", ""),
    }


def collect_buffer_metadata():
    filetype = _eval("&filetype", "") or ""
    buftype = _eval("&buftype", "") or ""
    is_modifiable = _as_bool(_eval("&modifiable", 1))
    is_readonly = _as_bool(_eval("&readonly", 0))
    is_buflisted = _as_bool(_eval("&buflisted", 1))
    cursor_line = _as_int(_eval("line('.')", 1), 1)
    cursor_col = _as_int(_eval("col('.')", 1), 1)
    total_lines = _as_int(_eval("line('$')", 0), 0)
    byte_size = _as_int(_eval("line2byte(line('$') + 1)", 0), 0)
    if byte_size < 0:
        byte_size = 0
    file_path = _eval("expand('%:p')", "") or ""
    return {
        "filetype": filetype,
        "buftype": buftype,
        "modifiable": is_modifiable,
        "readonly": is_readonly,
        "buflisted": is_buflisted,
        "cursor_line": cursor_line,
        "cursor_col": cursor_col,
        "total_lines": total_lines,
        "byte_size": byte_size,
        "file_path": file_path,
    }


def is_normal_buffer(metadata):
    if metadata["buftype"] != "":
        return False
    if not metadata["modifiable"] or metadata["readonly"]:
        return False
    if not metadata["buflisted"]:
        return False
    if metadata["filetype"] == "aichat":
        return False
    return True


def is_filetype_allowed(filetype, whitelist, blacklist):
    normalized = filetype or ""
    for pattern in blacklist:
        if fnmatch.fnmatchcase(normalized, pattern):
            return False
    for pattern in whitelist:
        if fnmatch.fnmatchcase(normalized, pattern):
            return True
    return False


def is_large_file(metadata, threshold):
    threshold_value = threshold or 0
    if threshold_value <= 0:
        return False
    return metadata["byte_size"] > threshold_value


def should_trigger_request(config=None, metadata=None):
    runtime_config = config or get_runtime_config()
    if not runtime_config["enabled"]:
        return False
    buffer_metadata = metadata or collect_buffer_metadata()
    if not is_normal_buffer(buffer_metadata):
        return False
    if not is_filetype_allowed(
        buffer_metadata["filetype"],
        runtime_config["whitelist"],
        runtime_config["blacklist"],
    ):
        return False
    if is_large_file(buffer_metadata, runtime_config["large_file_threshold"]):
        return False
    return True


def should_trigger():
    return should_trigger_request()


def _gather_context_lines(metadata, context_lines):
    cursor_line = metadata["cursor_line"]
    total_lines = metadata["total_lines"]
    before_start = max(1, cursor_line - context_lines)
    before_end = cursor_line - 1
    after_start = cursor_line + 1
    after_end = min(total_lines, cursor_line + context_lines)

    before_lines = []
    if before_end >= before_start:
        before_lines = _eval(f"getline({before_start}, {before_end})", []) or []
    if isinstance(before_lines, str):
        before_lines = [before_lines]

    after_lines = []
    if after_end >= after_start:
        after_lines = _eval(f"getline({after_start}, {after_end})", []) or []
    if isinstance(after_lines, str):
        after_lines = [after_lines]

    current_line = _eval("getline('.')", "") or ""
    cursor_col = metadata["cursor_col"]
    before_cursor = current_line[: max(cursor_col - 1, 0)]
    after_cursor = current_line[max(cursor_col - 1, 0) :]

    prefix_lines = before_lines + [before_cursor]
    suffix_lines = [after_cursor] + after_lines

    prefix = "\n".join(prefix_lines)
    suffix = "\n".join(suffix_lines)

    return {
        "prefix": prefix,
        "suffix": suffix,
        "filetype": metadata["filetype"],
        "file_path": metadata["file_path"],
    }


def build_fill_in_middle_prompt(metadata, context_lines):
    context = _gather_context_lines(metadata, context_lines)
    filetype_hint = context["filetype"] or "plain"
    location_hint = context["file_path"]

    header_lines = [
        "You complete the text between <fim_middle> and <fim_suffix> using the surrounding context.",
        "Use <fim_prefix> and <fim_suffix> as already-written code and respond with only the missing middle section.",
        "Do not repeat the prefix or suffix and avoid commentary or explanation.",
        f"Active filetype: {filetype_hint}",
    ]
    if location_hint:
        header_lines.append(f"Active file: {location_hint}")

    prompt_sections = [
        "\n".join(header_lines),
        FIM_PREFIX,
        context["prefix"],
        FIM_MIDDLE,
        FIM_SUFFIX,
        context["suffix"],
    ]

    prompt = "\n".join(prompt_sections)
    context["prompt"] = prompt
    return context


def make_provider_context(context_lines, model_override="", provider_override=""):
    base_config = _load_complete_base_config()
    config_extension = {}
    options_extension = {}
    if model_override:
        options_extension["model"] = model_override
    if options_extension:
        config_extension["options"] = options_extension
    if provider_override:
        config_extension["provider"] = provider_override
    context_input = {
        "config_default": base_config,
        "config_extension": config_extension,
        "user_instruction": "",
        "user_selection": "",
        "command_type": "complete",
    }
    provider_context = make_ai_context(context_input)
    metadata = collect_buffer_metadata()
    fim_context = build_fill_in_middle_prompt(metadata, context_lines)
    provider_context["prompt"] = fim_context["prompt"]
    if model_override:
        provider_context.setdefault("config", {}).setdefault("options", {})["model"] = model_override
    return provider_context


def fetch_completion_text(context):
    update_thread_shared_variables()
    command_type = context.get("command_type", "complete")
    prompt = context.get("prompt", "")
    config = make_config(context.get("config", {}))
    config_options = config.get("options", {})
    roles = context.get("roles", [])
    provider_name = config.get("provider", "")

    try:
        if not prompt and not roles:
            return ""

        if not provider_name:
            raise KnownError(
                "Missing provider configuration. Ensure g:vim_ai_complete defines a provider."
            )

        config_options["initial_prompt"] = []
        initial_prompt = config_options.get("initial_prompt", [])
        if isinstance(initial_prompt, list):
            initial_prompt = "\n".join(initial_prompt)

        chat_content = f"{initial_prompt}\n\n>>> user\n\n{prompt}".strip()
        messages = parse_chat_messages(chat_content)

        provider_class = load_provider(provider_name)
        provider = provider_class(command_type, config_options, ai_provider_utils)
        response_chunks = provider.request(messages)

        completion_parts = [
            chunk.get("content", "")
            for chunk in response_chunks
            if chunk.get("type") == "assistant"
        ]
        completion_text = "".join(completion_parts)
        if not completion_text.strip():
            raise KnownError('Empty response received. Tip: You can try modifying the prompt and retry.')
        return completion_text
    except BaseException as error:
        handle_completion_error(config.get("provider", ""), error)
        print_debug("[autocomplete] error: {}", traceback.format_exc())
        return ""
    finally:
        clear_echo_message()


def request_autocomplete(params):
    runtime_config = get_runtime_config()
    context_lines = params.get("context_lines", runtime_config["context_lines"])
    context_lines = _as_int(context_lines, runtime_config["context_lines"])
    model_override = runtime_config.get("model", "")
    provider_override = runtime_config.get("provider", "")

    provider_context = make_provider_context(context_lines, model_override, provider_override)
    completion = fetch_completion_text(provider_context)
    provider_context["completion"] = completion
    return provider_context
