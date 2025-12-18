#!/usr/bin/env python3
"""Thin pyatv helper for the Noctalia Apple TV plugin.

The helper exposes a small CLI that can either fetch the current playback
state or execute individual control commands. Every invocation connects to the
configured Apple TV, performs the requested action, emits JSON on stdout and
then disconnects.

Example usage:
  python3 appletv_helper.py \
      --identifier 0x1234567890abcdef \
      --address 192.168.1.42 \
      --mrp-credentials "..." \
      --command state

The helper depends on `pyatv` (https://github.com/postlund/pyatv). Install it
with `pip install pyatv` inside a virtualenv or system-wide environment.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional

try:
    import pyatv
    from pyatv import exceptions
    from pyatv.const import DeviceState, Protocol
except ImportError as exc:  # pragma: no cover - handled at runtime
    print(json.dumps({
        "success": False,
        "error": "pyatv is not installed: {}".format(exc),
    }))
    sys.exit(2)


@dataclass
class HelperConfig:
    identifier: Optional[str]
    address: Optional[str]
    name: Optional[str]
    mrp_credentials: Optional[str]
    companion_credentials: Optional[str]
    airplay_credentials: Optional[str]
    scan_timeout: int


async def resolve_device(loop: asyncio.AbstractEventLoop, cfg: HelperConfig):
    """Scan for an Apple TV that matches the provided identifier/name/address."""
    scan_kwargs: Dict[str, Any] = {
        "timeout": cfg.scan_timeout,
    }
    if cfg.identifier:
        scan_kwargs["identifier"] = cfg.identifier
    if cfg.address:
        scan_kwargs["address"] = cfg.address
    devices = await pyatv.scan(loop, **scan_kwargs)
    match = None
    if cfg.identifier:
        for device in devices:
            if device.identifier == cfg.identifier:
                match = device
                break
    if match is None and cfg.address:
        for device in devices:
            if device.address == cfg.address:
                match = device
                break
    if match is None and cfg.name:
        for device in devices:
            if (device.name or "").lower() == cfg.name.lower():
                match = device
                break
    if match is None and devices:
        match = devices[0]
    if not match:
        raise RuntimeError("Apple TV not found on the network")
    if cfg.mrp_credentials:
        match.set_credentials(Protocol.MRP, cfg.mrp_credentials)
    if cfg.airplay_credentials:
        match.set_credentials(Protocol.AirPlay, cfg.airplay_credentials)
    if cfg.companion_credentials:
        match.set_credentials(Protocol.Companion, cfg.companion_credentials)
    return match


async def gather_state(atv) -> Dict[str, Any]:
    metadata = await atv.metadata.playing()
    audio_level = None
    is_muted = False
    if atv.audio:
        try:
            audio_level = await atv.audio.volume()
        except Exception:  # pylint: disable=broad-except
            audio_level = None
        try:
            is_muted = await atv.audio.muted()
        except Exception:
            is_muted = False
    result = {
        "device_state": DeviceState.Idle.name.lower(),
        "title": None,
        "artist": None,
        "album": None,
        "position": None,
        "duration": None,
        "app": None,
        "updated": datetime.now(timezone.utc).isoformat(),
        "volume": audio_level,
        "is_muted": is_muted,
        "shuffle": None,
        "repeat": None,
    }
    if metadata:
        result["device_state"] = metadata.device_state.name.lower()
        result["title"] = metadata.title
        result["artist"] = getattr(metadata, "artist", None)
        result["album"] = getattr(metadata, "album", None)
        result["position"] = metadata.position
        result["duration"] = metadata.total_time
        result["app"] = getattr(metadata, "app", None)
    return result


async def handle_command(loop, args) -> Dict[str, Any]:
    cfg = HelperConfig(
        identifier=args.identifier,
        address=args.address,
        name=args.name,
        mrp_credentials=args.mrp_credentials,
        companion_credentials=args.companion_credentials,
        airplay_credentials=args.airplay_credentials,
        scan_timeout=args.scan_timeout,
    )
    device_conf = await resolve_device(loop, cfg)
    atv = None
    try:
        atv = await pyatv.connect(device_conf, loop)
        rc = atv.remote_control
        if args.command == "state":
            payload = await gather_state(atv)
            return {"success": True, "state": payload}
        if args.command in ("play", "pause", "stop", "next", "previous"):
            await getattr(rc, args.command)()
            return {"success": True}
        if args.command == "play_pause":
            await rc.play_pause()
            return {"success": True}
        if args.command == "seek":
            await rc.set_position(args.position)
            return {"success": True}
        if args.command == "set_volume":
            if not atv.audio:
                raise RuntimeError("Device does not expose audio controls")
            await atv.audio.set_volume(args.level)
            return {"success": True}
        if args.command == "volume_up":
            if not atv.audio:
                raise RuntimeError("Device does not expose audio controls")
            await atv.audio.volume_up()
            return {"success": True}
        if args.command == "volume_down":
            if not atv.audio:
                raise RuntimeError("Device does not expose audio controls")
            await atv.audio.volume_down()
            return {"success": True}
        if args.command == "mute":
            if not atv.audio:
                raise RuntimeError("Device does not expose audio controls")
            await atv.audio.mute()
            return {"success": True}
        if args.command == "unmute":
            if not atv.audio:
                raise RuntimeError("Device does not expose audio controls")
            await atv.audio.unmute()
            return {"success": True}
        raise RuntimeError(f"Unsupported command: {args.command}")
    finally:
        if atv is not None:
            await atv.close()


def parse_args(argv: Optional[list[str]] = None):
    parser = argparse.ArgumentParser(description="pyatv helper for Noctalia")
    parser.add_argument("--identifier", help="Apple TV identifier", default=None)
    parser.add_argument("--address", help="Apple TV IP address", default=None)
    parser.add_argument("--name", help="Friendly name to match when scanning", default=None)
    parser.add_argument("--mrp-credentials", help="MRP credentials", default=None)
    parser.add_argument("--companion-credentials", help="Companion credentials", default=None)
    parser.add_argument("--airplay-credentials", help="AirPlay credentials", default=None)
    parser.add_argument("--scan-timeout", type=int, default=8, help="Discovery timeout in seconds")
    parser.add_argument("--command", required=True,
                        choices=[
                            "state", "play", "pause", "stop", "next", "previous",
                            "play_pause", "seek", "set_volume", "volume_up",
                            "volume_down", "mute", "unmute"
                        ])
    parser.add_argument("--position", type=float, default=None, help="Seek position in seconds")
    parser.add_argument("--level", type=float, default=None, help="Volume level (0-1 range)")
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        result = loop.run_until_complete(handle_command(loop, args))
        print(json.dumps(result))
        return 0 if result.get("success") else 1
    except exceptions.AuthenticationError as exc:
        print(json.dumps({"success": False, "error": f"Authentication failed: {exc}"}))
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        print(json.dumps({"success": False, "error": str(exc)}))
        return 3
    finally:
        loop.close()


if __name__ == "__main__":
    sys.exit(main())
