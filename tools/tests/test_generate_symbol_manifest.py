from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from generate_symbol_manifest import (  # noqa: E402
    generate,
    parse_allowlist,
    parse_symbols,
)


class GenerateSymbolManifestTests(unittest.TestCase):
    def test_parses_rom0_and_romx_offsets(self) -> None:
        symbols = parse_symbols(
            "; generated\n"
            "00:1234 HomeLabel\n"
            "02:4567 BankedLabel\n"
            "2a CONSTANT_VALUE\n"
        )
        self.assertEqual(symbols["HomeLabel"].offset, 0x1234)
        self.assertEqual(symbols["BankedLabel"].offset, 0x8567)

    def test_rejects_invalid_windows_and_duplicates(self) -> None:
        with self.assertRaisesRegex(ValueError, "outside ROM0"):
            parse_symbols("00:4000 Invalid\n")["Invalid"].offset
        with self.assertRaisesRegex(ValueError, "duplicate"):
            parse_symbols("01:4000 Same\n01:4001 Same\n")

    def test_allowlist_is_ordered_and_unique(self) -> None:
        self.assertEqual(
            parse_allowlist("# comment\nSecond\nFirst # note\n"),
            ["Second", "First"],
        )
        with self.assertRaisesRegex(ValueError, "duplicate"):
            parse_allowlist("Same\nSame\n")

    def test_generation_checks_hash_and_is_deterministic(self) -> None:
        symbol_bytes = b"01:4000 Second\n00:0123 First\n"
        digest = hashlib.sha256(symbol_bytes).hexdigest()
        lock = {
            "repository": "https://example.invalid/reference",
            "sourceCommit": "1" * 40,
            "symbolsCommit": "2" * 40,
            "symbolsPath": "test.sym",
            "symbolsSha256": digest,
            "rgbdsVersion": "1.0.1",
            "romProfile": "test",
        }

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            symbols = root / "test.sym"
            allowlist = root / "allowlist.txt"
            lock_path = root / "lock.json"
            symbols.write_bytes(symbol_bytes)
            allowlist.write_text("Second\nFirst\n", encoding="utf-8")
            lock_path.write_text(json.dumps(lock), encoding="utf-8")

            first = generate(symbols, allowlist, lock_path)
            second = generate(symbols, allowlist, lock_path)
            self.assertEqual(first, second)
            self.assertIn('["First"]', first)
            self.assertIn("offset = 0x004000", first)

            symbols.write_bytes(symbol_bytes + b"; changed\n")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                generate(symbols, allowlist, lock_path)


if __name__ == "__main__":
    unittest.main()
