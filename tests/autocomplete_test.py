import pytest
from unittest.mock import patch

from autocomplete import (
    FIM_MIDDLE,
    FIM_PREFIX,
    FIM_SUFFIX,
    build_fill_in_middle_prompt,
    request_autocomplete,
    should_trigger_request,
)



def make_metadata(**overrides):
    base = {
        "filetype": "python",
        "buftype": "",
        "modifiable": True,
        "readonly": False,
        "buflisted": True,
        "byte_size": 128,
    }
    base.update(overrides)
    return base


def make_config(**overrides):
    base = {
        "enabled": True,
        "whitelist": ["*"],
        "blacklist": [],
        "large_file_threshold": 0,
    }
    base.update(overrides)
    return base


def test_should_trigger_request_disabled():
    config = make_config(enabled=False)
    metadata = make_metadata()
    assert should_trigger_request(config, metadata) is False


def test_should_trigger_respects_whitelist_and_blacklist():
    config = make_config(whitelist=["py*"], blacklist=["python.test"])
    metadata = make_metadata(filetype="python")
    assert should_trigger_request(config, metadata) is True

    metadata = make_metadata(filetype="python.test")
    assert should_trigger_request(config, metadata) is False

    metadata = make_metadata(filetype="markdown")
    assert should_trigger_request(config, metadata) is False


def test_should_trigger_blocks_large_file():
    config = make_config(large_file_threshold=1024)
    metadata = make_metadata(byte_size=500)
    assert should_trigger_request(config, metadata) is True

    metadata = make_metadata(byte_size=2048)
    assert should_trigger_request(config, metadata) is False


def test_should_trigger_requires_normal_buffer():
    config = make_config()
    assert should_trigger_request(config, make_metadata(buftype="nofile")) is False
    assert should_trigger_request(config, make_metadata(modifiable=False)) is False
    assert should_trigger_request(config, make_metadata(readonly=True)) is False
    assert should_trigger_request(config, make_metadata(buflisted=False)) is False
    assert should_trigger_request(config, make_metadata(filetype="aichat")) is False


def test_request_autocomplete_uses_context_lines():
    params = {"context_lines": 7}
    provider_context = {
        "prompt": "stub prompt",
        "metadata": {"prefix": "pre", "suffix": "post"},
    }

    with patch("autocomplete.make_provider_context", return_value=provider_context) as make_ctx, \
         patch("autocomplete.fetch_completion_text", return_value="print('hi')") as fetch:
        result = request_autocomplete(params)

    make_ctx.assert_called_once_with(7)
    fetch.assert_called_once_with(provider_context)
    assert result is provider_context
    assert result["completion"] == "print('hi')"
    assert result["prompt"] == provider_context["prompt"]
    assert result["metadata"] == provider_context["metadata"]


def test_build_fill_in_middle_prompt_contains_markers():
    metadata = {
        "cursor_line": 2,
        "cursor_col": 5,
        "total_lines": 3,
        "filetype": "python",
        "file_path": "/tmp/example.py",
    }

    def fake_eval(expr, default=None):
        mapping = {
            "getline(1, 1)": ["def greet(name):"],
            "getline(3, 3)": ["    return f'Hello {name}'"],
            "getline('.')": "    print(f'Hello {name}')",
        }
        return mapping.get(expr, default)

    with patch("autocomplete._eval", side_effect=fake_eval):
        context = build_fill_in_middle_prompt(metadata, 1)

    prompt = context["prompt"]
    assert FIM_PREFIX in prompt
    assert FIM_MIDDLE in prompt
    assert FIM_SUFFIX in prompt
    assert "Active filetype: python" in prompt
    assert "Active file: /tmp/example.py" in prompt
    assert "def greet(name):" in prompt
    assert "return f'Hello {name}'" in prompt
