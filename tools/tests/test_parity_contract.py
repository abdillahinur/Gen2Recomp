from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from parity_contract import (  # noqa: E402
    ContractError,
    compare_runs,
    load_run,
    load_scenario,
)


ROM_SHA1 = "f2f52230b536214ef7c9924f483392993e226cfb"
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def scenario_value() -> dict:
    return {
        "schema": 1,
        "id": "synthetic.parity.contract",
        "rom": {"profile": "crystal_us_11", "sha1": ROM_SHA1},
        "hardware": {"model": "cgb", "bootRom": False},
        "rtc": "2000-01-01T10:00:00Z",
        "initialState": {"kind": "power_on"},
        "inputs": [
            {"frame": 0, "buttons": []},
            {"frame": 1, "buttons": ["a"]},
        ],
        "checkpoints": {
            "frames": {
                "width": 2,
                "height": 1,
                "format": "rgba8888",
                "origin": "top_left",
                "at": [0, 1],
            },
            "states": [
                {"frame": 1, "required": ["screen", "selected"]}
            ],
            "audio": {
                "sampleRate": 48000,
                "channels": 2,
                "format": "pcm_s16le",
                "windows": [
                    {
                        "id": "opening",
                        "startFrame": 0,
                        "endFrame": 2,
                        "sampleCount": 2,
                    }
                ],
            },
        },
    }


def write_json(path: Path, value: object) -> bytes:
    payload = json.dumps(value, sort_keys=True).encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return payload


def write_run(
    root: Path,
    *,
    scenario: dict,
    frame_zero: bytes | None = None,
    frame_one: bytes | None = None,
    state: dict | None = None,
    audio: bytes | None = None,
) -> Path:
    frame_zero = frame_zero or bytes([1, 2, 3, 255, 4, 5, 6, 255])
    frame_one = frame_one or bytes([7, 8, 9, 255, 10, 11, 12, 255])
    state = state or {"screen": "gender", "selected": 0}
    audio = audio or bytes([1, 0, 2, 0, 3, 0, 4, 0])

    frame_zero_path = root / "frames" / "000000.rgba"
    frame_one_path = root / "frames" / "000001.rgba"
    state_path = root / "states" / "000001.json"
    audio_path = root / "audio" / "opening.pcm16le"
    for path, payload in (
        (frame_zero_path, frame_zero),
        (frame_one_path, frame_one),
        (audio_path, audio),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    state_payload = write_json(state_path, state)

    manifest = {
        "schema": 1,
        "scenario": "synthetic.parity.contract",
        "scenarioSha256": scenario["_sha256"],
        "producer": {
            "name": root.name,
            "version": "1.0",
            "configSha256": EMPTY_SHA256,
        },
        "frames": [
            {
                "frame": 0,
                "path": "frames/000000.rgba",
                "width": 2,
                "height": 1,
                "sha256": digest(frame_zero),
            },
            {
                "frame": 1,
                "path": "frames/000001.rgba",
                "width": 2,
                "height": 1,
                "sha256": digest(frame_one),
            },
        ],
        "states": [
            {
                "frame": 1,
                "path": "states/000001.json",
                "sha256": digest(state_payload),
            }
        ],
        "audio": [
            {
                "id": "opening",
                "startFrame": 0,
                "endFrame": 2,
                "path": "audio/opening.pcm16le",
                "sampleRate": 48000,
                "channels": 2,
                "sha256": digest(audio),
            }
        ],
    }
    manifest_path = root / "run.json"
    write_json(manifest_path, manifest)
    return manifest_path


class ParityContractTests(unittest.TestCase):
    def test_repository_example_validates(self) -> None:
        root = Path(__file__).resolve().parents[2]
        scenario = load_scenario(
            root
            / "manifests"
            / "parity"
            / "examples"
            / "contract_synthetic.json"
        )
        self.assertEqual(scenario["id"], "synthetic.parity.contract")

    def test_scenario_requires_sorted_frame_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenario.json"
            value = scenario_value()
            value["inputs"] = list(reversed(value["inputs"]))
            write_json(path, value)
            with self.assertRaisesRegex(ContractError, "sorted and unique"):
                load_scenario(path)

    def test_scenario_rejects_unknown_fields(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenario.json"
            value = scenario_value()
            value["claim"] = "parity"
            write_json(path, value)
            with self.assertRaisesRegex(ContractError, "unknown fields: claim"):
                load_scenario(path)

    def test_scenario_requires_canonical_utc_timestamp(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenario.json"
            value = scenario_value()
            value["rtc"] = "2000-01-01T10:00:00+00:00"
            write_json(path, value)
            with self.assertRaisesRegex(ContractError, "UTC timestamp"):
                load_scenario(path)

    def test_power_on_scenario_rejects_savestate_digest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenario.json"
            value = scenario_value()
            value["initialState"]["sha256"] = EMPTY_SHA256
            write_json(path, value)
            with self.assertRaisesRegex(ContractError, "only valid for savestate"):
                load_scenario(path)

    def test_identical_runs_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            reference = load_run(
                write_run(root / "reference", scenario=scenario), scenario
            )
            candidate = load_run(
                write_run(root / "candidate", scenario=scenario), scenario
            )
            self.assertEqual(compare_runs(scenario, reference, candidate), [])

    def test_reports_first_differing_pixel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            reference = load_run(
                write_run(root / "reference", scenario=scenario), scenario
            )
            changed = bytes([1, 2, 3, 255, 4, 99, 6, 255])
            candidate = load_run(
                write_run(
                    root / "candidate", scenario=scenario, frame_zero=changed
                ),
                scenario,
            )
            self.assertIn(
                "frame 0 pixel (1,0) differs",
                compare_runs(scenario, reference, candidate),
            )

    def test_rejects_missing_capture_frame(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(root / "candidate", scenario=scenario)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["frames"] = manifest["frames"][:1]
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ContractError, "frame inventory"):
                load_run(manifest_path, scenario)

    def test_rejects_run_from_different_scenario_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(root / "candidate", scenario=scenario)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["scenarioSha256"] = "0" * 64
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ContractError, "scenario file"):
                load_run(manifest_path, scenario)

    def test_rejects_state_missing_required_observation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(
                root / "candidate",
                scenario=scenario,
                state={"screen": "gender"},
            )
            with self.assertRaisesRegex(ContractError, "missing observations"):
                load_run(manifest_path, scenario)

    def test_reports_state_difference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            reference = load_run(
                write_run(root / "reference", scenario=scenario), scenario
            )
            candidate = load_run(
                write_run(
                    root / "candidate",
                    scenario=scenario,
                    state={"screen": "gender", "selected": 1},
                ),
                scenario,
            )
            self.assertIn(
                "state at frame 1 differs",
                compare_runs(scenario, reference, candidate),
            )

    def test_rejects_comparing_run_to_itself(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            run = load_run(
                write_run(root / "candidate", scenario=scenario), scenario
            )
            with self.assertRaisesRegex(ContractError, "must be distinct"):
                compare_runs(scenario, run, run)

    def test_reports_audio_channel_difference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            reference = load_run(
                write_run(root / "reference", scenario=scenario), scenario
            )
            changed = bytes([1, 0, 2, 0, 3, 0, 99, 0])
            candidate = load_run(
                write_run(
                    root / "candidate", scenario=scenario, audio=changed
                ),
                scenario,
            )
            self.assertIn(
                "audio opening sample 1 channel 1 differs",
                compare_runs(scenario, reference, candidate),
            )

    def test_rejects_artifact_digest_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(root / "candidate", scenario=scenario)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            changed = copy.deepcopy(manifest)
            changed["frames"][0]["sha256"] = "0" * 64
            write_json(manifest_path, changed)
            with self.assertRaisesRegex(ContractError, "SHA-256"):
                load_run(manifest_path, scenario)

    def test_rejects_non_stereo_audio(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(root / "candidate", scenario=scenario)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["audio"][0]["channels"] = 1
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ContractError, "channels must equal 2"):
                load_run(manifest_path, scenario)

    def test_rejects_audio_sample_count_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scenario_path = root / "scenario.json"
            write_json(scenario_path, scenario_value())
            scenario = load_scenario(scenario_path)
            manifest_path = write_run(
                root / "candidate",
                scenario=scenario,
                audio=bytes([1, 0, 2, 0]),
            )
            with self.assertRaisesRegex(ContractError, "sample count"):
                load_run(manifest_path, scenario)


if __name__ == "__main__":
    unittest.main()
