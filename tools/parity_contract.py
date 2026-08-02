#!/usr/bin/env python3
"""Validate and compare deterministic cartridge-parity run artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any


SCHEMA = 1
BUTTONS = {
    "a",
    "b",
    "down",
    "left",
    "right",
    "select",
    "start",
    "up",
}
SHA1 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SCENARIO_ID = re.compile(r"^[a-z][a-z0-9_.-]*$")
UTC_TIMESTAMP = "%Y-%m-%dT%H:%M:%SZ"
UTC_TIMESTAMP_PATTERN = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
)


class ContractError(ValueError):
    """Raised when a scenario or run manifest violates the parity contract."""


def _load_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ContractError(f"could not read JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise ContractError(f"{path} must contain a JSON object")
    return value


def _require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise ContractError(f"{field} must be a non-empty string")
    return value


def _require_integer(value: Any, field: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise ContractError(f"{field} must be an integer >= {minimum}")
    return value


def _require_array(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        raise ContractError(f"{field} must be an array")
    return value


def _require_object(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ContractError(f"{field} must be an object")
    return value


def _require_fields(
    value: dict[str, Any],
    required: set[str],
    field: str,
    optional: set[str] | None = None,
) -> None:
    optional = optional or set()
    missing = required - set(value)
    unknown = set(value) - required - optional
    if missing:
        raise ContractError(f"{field} is missing fields: {', '.join(sorted(missing))}")
    if unknown:
        raise ContractError(f"{field} has unknown fields: {', '.join(sorted(unknown))}")


def _require_digest(value: Any, field: str, pattern: re.Pattern[str]) -> str:
    digest = _require_string(value, field).lower()
    if not pattern.fullmatch(digest):
        raise ContractError(f"{field} has an invalid digest")
    return digest


def _require_sorted_unique(values: list[int], field: str) -> None:
    if values != sorted(set(values)):
        raise ContractError(f"{field} must be sorted and unique")


def load_scenario(path: Path | str) -> dict[str, Any]:
    """Load and validate one frame-indexed input/checkpoint scenario."""

    scenario_path = Path(path)
    scenario = _load_object(scenario_path)
    _require_fields(
        scenario,
        {"schema", "id", "rom", "hardware", "rtc", "initialState", "inputs", "checkpoints"},
        "scenario",
    )
    if scenario.get("schema") != SCHEMA:
        raise ContractError("scenario.schema must equal 1")
    scenario_id = _require_string(scenario.get("id"), "scenario.id")
    if not SCENARIO_ID.fullmatch(scenario_id):
        raise ContractError("scenario.id has an invalid stable ID")

    rom = _require_object(scenario.get("rom"), "scenario.rom")
    _require_fields(rom, {"profile", "sha1"}, "scenario.rom")
    _require_string(rom.get("profile"), "scenario.rom.profile")
    _require_digest(rom.get("sha1"), "scenario.rom.sha1", SHA1)

    hardware = _require_object(
        scenario.get("hardware"), "scenario.hardware"
    )
    _require_fields(hardware, {"model", "bootRom"}, "scenario.hardware")
    if hardware.get("model") not in {"cgb", "dmg"}:
        raise ContractError("scenario.hardware.model must be cgb or dmg")
    if not isinstance(hardware.get("bootRom"), bool):
        raise ContractError("scenario.hardware.bootRom must be boolean")

    rtc = _require_string(scenario.get("rtc"), "scenario.rtc")
    try:
        if not UTC_TIMESTAMP_PATTERN.fullmatch(rtc):
            raise ValueError("timestamp is not in canonical UTC form")
        datetime.strptime(rtc, UTC_TIMESTAMP)
    except ValueError as error:
        raise ContractError(
            "scenario.rtc must be a UTC timestamp like 2000-01-01T10:00:00Z"
        ) from error
    initial = _require_object(
        scenario.get("initialState"), "scenario.initialState"
    )
    _require_fields(
        initial,
        {"kind"},
        "scenario.initialState",
        optional={"sha256"},
    )
    if initial.get("kind") not in {"power_on", "savestate"}:
        raise ContractError(
            "scenario.initialState.kind must be power_on or savestate"
        )
    if initial["kind"] == "savestate":
        _require_digest(
            initial.get("sha256"),
            "scenario.initialState.sha256",
            SHA256,
        )
    elif "sha256" in initial:
        raise ContractError(
            "scenario.initialState.sha256 is only valid for savestate"
        )

    input_frames: list[int] = []
    for index, item in enumerate(
        _require_array(scenario.get("inputs"), "scenario.inputs")
    ):
        entry = _require_object(item, f"scenario.inputs[{index}]")
        _require_fields(
            entry,
            {"frame", "buttons"},
            f"scenario.inputs[{index}]",
        )
        input_frames.append(
            _require_integer(
                entry.get("frame"), f"scenario.inputs[{index}].frame"
            )
        )
        buttons = _require_array(
            entry.get("buttons"), f"scenario.inputs[{index}].buttons"
        )
        if len(buttons) != len(set(buttons)):
            raise ContractError(
                f"scenario.inputs[{index}].buttons contains duplicates"
            )
        for button in buttons:
            if button not in BUTTONS:
                raise ContractError(
                    f"scenario.inputs[{index}] has unknown button {button}"
                )
    _require_sorted_unique(input_frames, "scenario input frames")

    checkpoints = _require_object(
        scenario.get("checkpoints"), "scenario.checkpoints"
    )
    _require_fields(
        checkpoints,
        {"frames", "states", "audio"},
        "scenario.checkpoints",
    )
    video = _require_object(
        checkpoints.get("frames"), "scenario.checkpoints.frames"
    )
    _require_fields(
        video,
        {"width", "height", "format", "origin", "at"},
        "scenario.checkpoints.frames",
    )
    _require_integer(video.get("width"), "scenario.checkpoints.frames.width", 1)
    _require_integer(video.get("height"), "scenario.checkpoints.frames.height", 1)
    if video.get("format") != "rgba8888":
        raise ContractError("scenario.checkpoints.frames.format must be rgba8888")
    if video.get("origin") != "top_left":
        raise ContractError("scenario.checkpoints.frames.origin must be top_left")
    frame_checkpoints = [
        _require_integer(value, f"scenario.checkpoints.frames[{index}]")
        for index, value in enumerate(
            _require_array(
                video.get("at"), "scenario.checkpoints.frames.at"
            )
        )
    ]
    _require_sorted_unique(frame_checkpoints, "scenario frame checkpoints")

    state_frames: list[int] = []
    for index, item in enumerate(
        _require_array(checkpoints.get("states"), "scenario.checkpoints.states")
    ):
        entry = _require_object(item, f"scenario.checkpoints.states[{index}]")
        _require_fields(
            entry,
            {"frame", "required"},
            f"scenario.checkpoints.states[{index}]",
        )
        state_frames.append(
            _require_integer(
                entry.get("frame"), f"scenario.checkpoints.states[{index}].frame"
            )
        )
        required = _require_array(
            entry.get("required"), f"scenario.checkpoints.states[{index}].required"
        )
        if not required:
            raise ContractError(
                f"scenario.checkpoints.states[{index}].required must not be empty"
            )
        for key in required:
            _require_string(key, f"scenario.checkpoints.states[{index}].required")
        if required != sorted(set(required)):
            raise ContractError(
                f"scenario.checkpoints.states[{index}].required must be sorted and unique"
            )
    _require_sorted_unique(state_frames, "scenario state checkpoints")

    audio_contract = _require_object(
        checkpoints.get("audio"), "scenario.checkpoints.audio"
    )
    _require_fields(
        audio_contract,
        {"sampleRate", "channels", "format", "windows"},
        "scenario.checkpoints.audio",
    )
    _require_integer(
        audio_contract.get("sampleRate"),
        "scenario.checkpoints.audio.sampleRate",
        1,
    )
    if audio_contract.get("channels") != 2:
        raise ContractError("scenario.checkpoints.audio.channels must equal 2")
    if audio_contract.get("format") != "pcm_s16le":
        raise ContractError(
            "scenario.checkpoints.audio.format must be pcm_s16le"
        )
    audio_ids: list[str] = []
    for index, item in enumerate(
        _require_array(
            audio_contract.get("windows"), "scenario.checkpoints.audio.windows"
        )
    ):
        entry = _require_object(
            item, f"scenario.checkpoints.audio.windows[{index}]"
        )
        _require_fields(
            entry,
            {"id", "startFrame", "endFrame", "sampleCount"},
            f"scenario.checkpoints.audio.windows[{index}]",
        )
        audio_ids.append(
            _require_string(
                entry.get("id"),
                f"scenario.checkpoints.audio.windows[{index}].id",
            )
        )
        start = _require_integer(
            entry.get("startFrame"),
            f"scenario.checkpoints.audio.windows[{index}].startFrame",
        )
        end = _require_integer(
            entry.get("endFrame"),
            f"scenario.checkpoints.audio.windows[{index}].endFrame",
        )
        _require_integer(
            entry.get("sampleCount"),
            f"scenario.checkpoints.audio.windows[{index}].sampleCount",
            1,
        )
        if end <= start:
            raise ContractError(
                f"scenario.checkpoints.audio.windows[{index}] must end after start"
            )
    if len(audio_ids) != len(set(audio_ids)):
        raise ContractError("scenario audio checkpoint IDs must be unique")
    scenario["_sha256"] = hashlib.sha256(scenario_path.read_bytes()).hexdigest()
    return scenario


def _artifact_path(root: Path, value: Any, field: str, suffix: str) -> Path:
    raw = _require_string(value, field)
    relative = Path(raw)
    if relative.is_absolute() or ".." in relative.parts:
        raise ContractError(f"{field} must be a safe relative path")
    if relative.suffix.lower() != suffix:
        raise ContractError(f"{field} must use the {suffix} extension")
    target = (root / relative).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError as error:
        raise ContractError(f"{field} escapes its artifact root") from error
    return target


def _verify_artifact(
    root: Path,
    entry: dict[str, Any],
    field: str,
    suffix: str,
) -> Path:
    target = _artifact_path(root, entry.get("path"), field, suffix)
    expected = _require_digest(entry.get("sha256"), f"{field}.sha256", SHA256)
    try:
        payload = target.read_bytes()
    except OSError as error:
        raise ContractError(f"could not read artifact {target}: {error}") from error
    actual = hashlib.sha256(payload).hexdigest()
    if actual != expected:
        raise ContractError(f"{field} SHA-256 does not match {target}")
    return target


def load_run(
    path: Path | str, scenario: dict[str, Any]
) -> dict[str, Any]:
    """Load a run manifest and verify its artifact inventory and digests."""

    run_path = Path(path)
    run = _load_object(run_path)
    _require_fields(
        run,
        {
            "schema",
            "scenario",
            "scenarioSha256",
            "producer",
            "frames",
            "states",
            "audio",
        },
        "run",
    )
    if run.get("schema") != SCHEMA:
        raise ContractError("run.schema must equal 1")
    if run.get("scenario") != scenario["id"]:
        raise ContractError("run.scenario does not match the scenario ID")
    if _require_digest(
        run.get("scenarioSha256"), "run.scenarioSha256", SHA256
    ) != scenario["_sha256"]:
        raise ContractError("run.scenarioSha256 does not match the scenario file")
    producer = _require_object(run.get("producer"), "run.producer")
    _require_fields(
        producer,
        {"name", "version", "configSha256"},
        "run.producer",
    )
    _require_string(producer.get("name"), "run.producer.name")
    _require_string(producer.get("version"), "run.producer.version")
    _require_digest(
        producer.get("configSha256"),
        "run.producer.configSha256",
        SHA256,
    )

    root = run_path.resolve().parent
    frames: dict[int, dict[str, Any]] = {}
    for index, item in enumerate(_require_array(run.get("frames"), "run.frames")):
        entry = _require_object(item, f"run.frames[{index}]")
        _require_fields(
            entry,
            {"frame", "path", "width", "height", "sha256"},
            f"run.frames[{index}]",
        )
        frame = _require_integer(entry.get("frame"), f"run.frames[{index}].frame")
        if frame in frames:
            raise ContractError(f"run.frames contains duplicate frame {frame}")
        width = _require_integer(
            entry.get("width"), f"run.frames[{index}].width", 1
        )
        height = _require_integer(
            entry.get("height"), f"run.frames[{index}].height", 1
        )
        target = _verify_artifact(
            root, entry, f"run.frames[{index}]", ".rgba"
        )
        if target.stat().st_size != width * height * 4:
            raise ContractError(
                f"run.frames[{index}] is not width*height RGBA bytes"
            )
        entry["_artifact"] = target
        frames[frame] = entry

    video = scenario["checkpoints"]["frames"]
    expected_frames = video["at"]
    if sorted(frames) != expected_frames:
        raise ContractError("run frame inventory does not match scenario checkpoints")
    for frame, entry in frames.items():
        if (entry["width"], entry["height"]) != (
            video["width"],
            video["height"],
        ):
            raise ContractError(
                f"run frame {frame} dimensions do not match the scenario"
            )

    states: dict[int, dict[str, Any]] = {}
    for index, item in enumerate(_require_array(run.get("states"), "run.states")):
        entry = _require_object(item, f"run.states[{index}]")
        _require_fields(
            entry,
            {"frame", "path", "sha256"},
            f"run.states[{index}]",
        )
        frame = _require_integer(entry.get("frame"), f"run.states[{index}].frame")
        if frame in states:
            raise ContractError(f"run.states contains duplicate frame {frame}")
        entry["_artifact"] = _verify_artifact(
            root, entry, f"run.states[{index}]", ".json"
        )
        states[frame] = entry
    state_contracts = {
        entry["frame"]: entry for entry in scenario["checkpoints"]["states"]
    }
    if sorted(states) != sorted(state_contracts):
        raise ContractError("run state inventory does not match scenario checkpoints")
    for frame, entry in states.items():
        try:
            state_value = json.loads(entry["_artifact"].read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as error:
            raise ContractError(f"invalid state JSON at frame {frame}: {error}") from error
        state_object = _require_object(state_value, f"state artifact at frame {frame}")
        missing = set(state_contracts[frame]["required"]) - set(state_object)
        if missing:
            raise ContractError(
                f"state artifact at frame {frame} is missing observations: "
                f"{', '.join(sorted(missing))}"
            )

    audio: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(_require_array(run.get("audio"), "run.audio")):
        entry = _require_object(item, f"run.audio[{index}]")
        _require_fields(
            entry,
            {
                "id",
                "startFrame",
                "endFrame",
                "path",
                "sampleRate",
                "channels",
                "sha256",
            },
            f"run.audio[{index}]",
        )
        audio_id = _require_string(entry.get("id"), f"run.audio[{index}].id")
        if audio_id in audio:
            raise ContractError(f"run.audio contains duplicate ID {audio_id}")
        _require_integer(entry.get("startFrame"), f"run.audio[{index}].startFrame")
        _require_integer(entry.get("endFrame"), f"run.audio[{index}].endFrame")
        _require_integer(entry.get("sampleRate"), f"run.audio[{index}].sampleRate", 1)
        channels = _require_integer(
            entry.get("channels"), f"run.audio[{index}].channels", 1
        )
        if channels != 2:
            raise ContractError(f"run.audio[{index}].channels must equal 2")
        entry["_artifact"] = _verify_artifact(
            root, entry, f"run.audio[{index}]", ".pcm16le"
        )
        if entry["_artifact"].stat().st_size % (entry["channels"] * 2) != 0:
            raise ContractError(
                f"run.audio[{index}] is not interleaved 16-bit PCM"
            )
        audio[audio_id] = entry

    audio_contract = scenario["checkpoints"]["audio"]
    expected_audio = {
        entry["id"]: entry for entry in audio_contract["windows"]
    }
    if set(audio) != set(expected_audio):
        raise ContractError("run audio inventory does not match scenario checkpoints")
    for audio_id, expected in expected_audio.items():
        actual = audio[audio_id]
        if actual["startFrame"] != expected["startFrame"] or actual[
            "endFrame"
        ] != expected["endFrame"]:
            raise ContractError(
                f"run audio window {audio_id} does not match the scenario"
            )
        if actual["sampleRate"] != audio_contract["sampleRate"]:
            raise ContractError(
                f"run audio window {audio_id} sample rate does not match the scenario"
            )
        if actual["channels"] != audio_contract["channels"]:
            raise ContractError(
                f"run audio window {audio_id} channels do not match the scenario"
            )
        byte_count = actual["_artifact"].stat().st_size
        expected_bytes = expected["sampleCount"] * actual["channels"] * 2
        if byte_count != expected_bytes:
            raise ContractError(
                f"run audio window {audio_id} sample count does not match the scenario"
            )

    run["_manifestPath"] = run_path.resolve()
    run["_artifactRoot"] = root
    run["_frames"] = frames
    run["_states"] = states
    run["_audio"] = audio
    return run


def _compare_frames(
    reference: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    problems: list[str] = []
    for frame in sorted(reference["_frames"]):
        left = reference["_frames"][frame]
        right = candidate["_frames"][frame]
        if (left["width"], left["height"]) != (
            right["width"],
            right["height"],
        ):
            problems.append(f"frame {frame} dimensions differ")
            continue
        left_bytes = left["_artifact"].read_bytes()
        right_bytes = right["_artifact"].read_bytes()
        if left_bytes == right_bytes:
            continue
        for offset in range(0, len(left_bytes), 4):
            if left_bytes[offset : offset + 4] != right_bytes[offset : offset + 4]:
                pixel = offset // 4
                x = pixel % left["width"]
                y = pixel // left["width"]
                problems.append(f"frame {frame} pixel ({x},{y}) differs")
                break
    return problems


def _compare_states(
    reference: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    problems: list[str] = []
    for frame in sorted(reference["_states"]):
        left_path = reference["_states"][frame]["_artifact"]
        right_path = candidate["_states"][frame]["_artifact"]
        try:
            left = json.loads(left_path.read_text(encoding="utf-8"))
            right = json.loads(right_path.read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as error:
            raise ContractError(f"invalid state JSON at frame {frame}: {error}") from error
        if left != right:
            problems.append(f"state at frame {frame} differs")
    return problems


def _sample(payload: bytes, sample_index: int, channel: int, channels: int) -> int:
    offset = (sample_index * channels + channel) * 2
    return int.from_bytes(payload[offset : offset + 2], "little", signed=True)


def _compare_audio(
    reference: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    problems: list[str] = []
    for audio_id in sorted(reference["_audio"]):
        left = reference["_audio"][audio_id]
        right = candidate["_audio"][audio_id]
        metadata = ("startFrame", "endFrame", "sampleRate", "channels")
        differing = [field for field in metadata if left[field] != right[field]]
        if differing:
            problems.append(
                f"audio {audio_id} metadata differs: {', '.join(differing)}"
            )
            continue
        left_bytes = left["_artifact"].read_bytes()
        right_bytes = right["_artifact"].read_bytes()
        if len(left_bytes) != len(right_bytes):
            problems.append(f"audio {audio_id} sample count differs")
            continue
        if left_bytes == right_bytes:
            continue
        channels = left["channels"]
        sample_count = len(left_bytes) // (channels * 2)
        found = False
        for sample_index in range(sample_count):
            for channel in range(channels):
                if _sample(left_bytes, sample_index, channel, channels) != _sample(
                    right_bytes, sample_index, channel, channels
                ):
                    problems.append(
                        f"audio {audio_id} sample {sample_index} "
                        f"channel {channel} differs"
                    )
                    found = True
                    break
            if found:
                break
    return problems


def compare_runs(
    scenario: dict[str, Any],
    reference: dict[str, Any],
    candidate: dict[str, Any],
) -> list[str]:
    """Return precise mismatch descriptions for two validated runs."""

    if reference["scenario"] != scenario["id"]:
        raise ContractError("reference run does not match scenario")
    if candidate["scenario"] != scenario["id"]:
        raise ContractError("candidate run does not match scenario")
    if reference["_manifestPath"] == candidate["_manifestPath"]:
        raise ContractError("reference and candidate manifests must be distinct")
    if reference["_artifactRoot"] == candidate["_artifactRoot"]:
        raise ContractError("reference and candidate artifact roots must be distinct")
    return (
        _compare_frames(reference, candidate)
        + _compare_states(reference, candidate)
        + _compare_audio(reference, candidate)
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    args = parser.parse_args()
    try:
        scenario = load_scenario(args.scenario)
        reference = load_run(args.reference, scenario)
        candidate = load_run(args.candidate, scenario)
        problems = compare_runs(scenario, reference, candidate)
    except ContractError as error:
        print(f"Parity contract failed: {error}")
        return 2
    if problems:
        print("Parity comparison failed:")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print(f"Parity comparison passed: {scenario['id']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
