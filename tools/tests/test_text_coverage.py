import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEXT_ID = re.compile(r'"(crystal\.text\.[A-Za-z0-9_.]+)"')
MENU_ONLY = {
    "crystal.text.player_gender.boy",
    "crystal.text.player_gender.girl",
}


class CrystalTextCoverageTests(unittest.TestCase):
    def test_supported_scripts_have_no_dialogue_fallbacks(self):
        manifest = (ROOT / "manifests" / "crystal_text.lua").read_text(
            encoding="utf-8"
        )
        mapped = set(TEXT_ID.findall(manifest))
        requested = set()
        scripts = ROOT / "data" / "scripts" / "crystal"
        for path in scripts.rglob("*.lua"):
            requested.update(
                TEXT_ID.findall(path.read_text(encoding="utf-8"))
            )
        self.assertEqual([], sorted(requested - mapped - MENU_ONLY))


if __name__ == "__main__":
    unittest.main()
