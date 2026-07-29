"""Gemini request-boundary checks that never make a network call."""

from __future__ import annotations

import asyncio
import json
import os
import unittest
from typing import Any
from unittest.mock import patch

from app import llm


class _SuccessfulGeminiResponse:
    status_code = 200
    text = ""

    def json(self) -> dict[str, Any]:
        return {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": json.dumps(
                                    {
                                        "verdict": None,
                                        "error": {
                                            "type": "malformed_case",
                                            "detail": "test response",
                                        },
                                        "overall": None,
                                        "routes": [],
                                        "reasoning": "test response",
                                    }
                                )
                            }
                        ]
                    }
                }
            ]
        }


class _RecordingAsyncClient:
    last_payload: dict[str, Any] | None = None

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        pass

    async def __aenter__(self) -> "_RecordingAsyncClient":
        return self

    async def __aexit__(self, *args: Any) -> None:
        return None

    async def post(self, *args: Any, **kwargs: Any) -> _SuccessfulGeminiResponse:
        type(self).last_payload = kwargs["json"]
        return _SuccessfulGeminiResponse()


class GeminiPromptContractTests(unittest.TestCase):
    def test_payload_explains_dual_value_precedence_and_unknown_fallback(
        self,
    ) -> None:
        """Omitting a valuation-precedence rule would leave Gemini a different contract."""
        raw_case = b'{"estate":{"assets":[{"gross_value_cents":100}]}}'
        _RecordingAsyncClient.last_payload = None

        with (
            patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"}, clear=False),
            patch.object(llm.httpx, "AsyncClient", _RecordingAsyncClient),
        ):
            asyncio.run(llm.analyze_llm(raw_case))

        payload = _RecordingAsyncClient.last_payload
        self.assertIsNotNone(payload)
        instruction = payload["system_instruction"]["parts"][0]["text"]
        self.assertIn(
            "`current_gross_value_cents` governs current-value rules when supplied",
            instruction,
        )
        self.assertIn(
            "`date_of_death_value_cents` governs date-of-death rules when supplied",
            instruction,
        )
        self.assertIn(
            "`gross_value_cents` is the backward-compatible fallback for either "
            "exact field when the corresponding explicit field is omitted or null",
            instruction,
        )
        self.assertIn(
            "both absent or null, that valuation fact remains UNKNOWN — never false "
            "or zero",
            instruction,
        )
