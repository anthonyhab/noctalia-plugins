#!/usr/bin/env python3
"""
Waybar to Noctalia Converter

Converts Waybar custom module configurations to Noctalia CustomButton widgets
or full plugin scaffolds.

Usage:
    python waybar_to_noctalia.py [waybar_config_path] [--output-dir DIR] [--mode MODE]

Modes:
    widgets  - Generate CustomButton widget configurations (default)
    plugins  - Generate full plugin scaffolds for each module
    both     - Generate both widgets and plugins
"""

from __future__ import annotations

import argparse
import base64
import json
import shlex
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional


DEFAULT_WAYBAR_INTERVAL = 60


@dataclass
class WaybarModule:
    """Represents a parsed Waybar custom module."""
    name: str
    source: str
    exec_cmd: str = ""
    exec_if: str = ""
    interval: Optional[int] = None
    interval_mode: str = "poll"  # "poll" or "once"
    interval_defaulted: bool = False
    interval_signal_override: bool = False
    signal: Optional[int] = None
    format: str = "{}"
    format_icons: list = field(default_factory=list)
    return_type: str = ""  # "json" or ""
    max_length: Optional[int] = None
    min_length: Optional[int] = None
    tooltip: bool = True
    on_click: str = ""
    on_click_middle: str = ""
    on_click_right: str = ""
    on_scroll_up: str = ""
    on_scroll_down: str = ""
    escape: bool = False
    exec_on_event: bool = True
    restart_interval: Optional[int] = None


@dataclass
class NoctaliaWidgetConfig:
    """Represents a Noctalia CustomButton widget configuration."""
    textCommand: str
    textStream: Optional[bool] = None
    textIntervalMs: Optional[int] = None
    parseJson: Optional[bool] = None
    leftClickExec: Optional[str] = None
    leftClickUpdateText: Optional[bool] = None
    rightClickExec: Optional[str] = None
    rightClickUpdateText: Optional[bool] = None
    middleClickExec: Optional[str] = None
    middleClickUpdateText: Optional[bool] = None
    wheelUpExec: Optional[str] = None
    wheelDownExec: Optional[str] = None
    wheelMode: Optional[str] = None
    wheelUpUpdateText: Optional[bool] = None
    wheelDownUpdateText: Optional[bool] = None
    maxTextLength: Optional[dict] = None

    def to_dict(self) -> dict:
        data: dict[str, object] = {"type": "CustomButton", "textCommand": self.textCommand}
        optional_fields = {
            "textStream": self.textStream,
            "textIntervalMs": self.textIntervalMs,
            "parseJson": self.parseJson,
            "leftClickExec": self.leftClickExec,
            "leftClickUpdateText": self.leftClickUpdateText,
            "rightClickExec": self.rightClickExec,
            "rightClickUpdateText": self.rightClickUpdateText,
            "middleClickExec": self.middleClickExec,
            "middleClickUpdateText": self.middleClickUpdateText,
            "wheelUpExec": self.wheelUpExec,
            "wheelDownExec": self.wheelDownExec,
            "wheelMode": self.wheelMode,
            "wheelUpUpdateText": self.wheelUpUpdateText,
            "wheelDownUpdateText": self.wheelDownUpdateText,
            "maxTextLength": self.maxTextLength,
        }

        for key, value in optional_fields.items():
            if value is None:
                continue
            if isinstance(value, bool) and value is False:
                continue
            if isinstance(value, str) and value == "":
                continue
            data[key] = value

        return data


@dataclass
class TransformResult:
    command: str
    parse_json: bool
    warnings: list[str] = field(default_factory=list)


def remove_trailing_commas(content: str) -> str:
    """Remove trailing commas before closing brackets while preserving strings."""
    result: list[str] = []
    in_string = False
    escape_next = False

    for char in content:
        if escape_next:
            result.append(char)
            escape_next = False
            continue

        if in_string and char == "\\":
            result.append(char)
            escape_next = True
            continue

        if char == '"':
            in_string = not in_string
            result.append(char)
            continue

        if not in_string and char in "]}":
            idx = len(result) - 1
            while idx >= 0 and result[idx].isspace():
                idx -= 1
            if idx >= 0 and result[idx] == ",":
                result.pop(idx)

        result.append(char)

    return "".join(result)


def strip_jsonc_comments(content: str) -> str:
    """Remove C-style comments from JSONC content while preserving strings."""
    result = []
    i = 0
    in_string = False
    escape_next = False

    while i < len(content):
        char = content[i]

        if escape_next:
            result.append(char)
            escape_next = False
            i += 1
            continue

        if char == "\\" and in_string:
            result.append(char)
            escape_next = True
            i += 1
            continue

        if char == '"' and not escape_next:
            in_string = not in_string
            result.append(char)
            i += 1
            continue

        if not in_string:
            if char == "/" and i + 1 < len(content) and content[i + 1] == "/":
                while i < len(content) and content[i] != "\n":
                    i += 1
                continue

            if char == "/" and i + 1 < len(content) and content[i + 1] == "*":
                i += 2
                while i + 1 < len(content):
                    if content[i] == "*" and content[i + 1] == "/":
                        i += 2
                        break
                    i += 1
                continue

        result.append(char)
        i += 1

    cleaned = "".join(result)
    return remove_trailing_commas(cleaned)


def parse_waybar_config(config_path: Path) -> object:
    """Parse a Waybar JSONC configuration file."""
    with open(config_path, "r", encoding="utf-8") as f:
        content = f.read()

    clean_json = strip_jsonc_comments(content)

    try:
        return json.loads(clean_json)
    except json.JSONDecodeError as e:
        print(f"Error parsing Waybar config: {e}")
        print(f"Problematic content near position {e.pos}:")
        start = max(0, e.pos - 50)
        end = min(len(clean_json), e.pos + 50)
        print(clean_json[start:end])
        sys.exit(1)


def iter_config_dicts(config: object) -> Iterable[tuple[str, dict]]:
    if isinstance(config, list):
        for idx, item in enumerate(config):
            if isinstance(item, dict):
                yield f"config[{idx}]", item
    elif isinstance(config, dict):
        yield "config", config


def normalize_interval(raw_value: object, default_interval: int) -> tuple[str, int, bool]:
    if raw_value is None:
        return "poll", default_interval, True

    if isinstance(raw_value, str):
        if raw_value.lower() == "once":
            return "once", 0, False
        try:
            parsed = int(float(raw_value))
        except ValueError:
            return "poll", default_interval, True
    elif isinstance(raw_value, (int, float)):
        parsed = int(raw_value)
    else:
        return "poll", default_interval, True

    if parsed <= 0:
        return "once", 0, False

    return "poll", parsed, False


def extract_custom_modules(
    config: object, default_interval: int, signal_poll_interval: int
) -> list[WaybarModule]:
    """Extract custom modules from Waybar config."""
    modules: list[WaybarModule] = []

    for source, section in iter_config_dicts(config):
        for key, value in section.items():
            if key.startswith("custom/") and isinstance(value, dict):
                module_name = key.replace("custom/", "", 1)
                module = WaybarModule(name=module_name, source=source)

                module.exec_cmd = value.get("exec", "")
                module.exec_if = value.get("exec-if", "")
                module.format = value.get("format", "{}")
                module.format_icons = value.get("format-icons", [])
                module.return_type = value.get("return-type", "")
                module.max_length = value.get("max-length")
                module.min_length = value.get("min-length")
                module.tooltip = value.get("tooltip", True)
                module.on_click = value.get("on-click", "")
                module.on_click_middle = value.get("on-click-middle", "")
                module.on_click_right = value.get("on-click-right", "")
                module.on_scroll_up = value.get("on-scroll-up", "")
                module.on_scroll_down = value.get("on-scroll-down", "")
                module.escape = value.get("escape", False)
                module.exec_on_event = value.get("exec-on-event", True)
                module.restart_interval = value.get("restart-interval")
                module.signal = value.get("signal")

                interval_mode, interval, defaulted = normalize_interval(
                    value.get("interval"), default_interval
                )
                if defaulted and module.signal and signal_poll_interval > 0:
                    interval_mode = "poll"
                    interval = signal_poll_interval
                    defaulted = False
                    module.interval_signal_override = True
                module.interval_mode = interval_mode
                module.interval = interval
                module.interval_defaulted = defaulted

                modules.append(module)

    return dedupe_modules(modules)


def dedupe_modules(modules: list[WaybarModule]) -> list[WaybarModule]:
    seen: dict[str, int] = {}
    for module in modules:
        base_name = module.name
        count = seen.get(base_name, 0)
        if count:
            module.name = f"{base_name}-{count + 1}"
        seen[base_name] = count + 1
    return modules


def build_exec_if_wrapper(exec_cmd: str, exec_if: str) -> str:
    if not exec_if:
        return exec_cmd
    return f"if {exec_if}; then {exec_cmd}; fi"


def build_python_json_transform(exec_cmd: str, format_str: str, format_icons: list) -> str:
    icons_b64 = base64.b64encode(json.dumps(format_icons).encode("utf-8")).decode("ascii")
    fmt_b64 = base64.b64encode(format_str.encode("utf-8")).decode("ascii")

    python_code = (
        "import base64,json,sys;"
        "def safe_int(val):\n"
        "  try:\n"
        "    return int(float(val))\n"
        "  except Exception:\n"
        "    return None\n"
        "def apply_format(fmt, data, icon):\n"
        "  if fmt in ('{}','{text}'): return data.get('text','')\n"
        "  out = fmt.replace('{}', str(data.get('text','')));\n"
        "  replacements = {\n"
        "    '{text}': str(data.get('text','')),\n"
        "    '{icon}': str(icon),\n"
        "    '{percentage}': str(data.get('percentage','')) ,\n"
        "    '{class}': str(data.get('class','')),\n"
        "    '{alt}': str(data.get('alt','')),\n"
        "  }\n"
        "  for key, value in replacements.items():\n"
        "    out = out.replace(key, value)\n"
        "  return out\n"
        "icons = json.loads(base64.b64decode(sys.argv[1] or 'W10='))\n"
        "fmt = base64.b64decode(sys.argv[2] or 'e30=').decode('utf-8', 'ignore')\n"
        "raw = sys.stdin.read()\n"
        "raw = raw.strip()\n"
        "if not raw:\n"
        "  sys.exit(0)\n"
        "try:\n"
        "  data = json.loads(raw)\n"
        "except Exception:\n"
        "  data = {'text': raw, 'tooltip': raw}\n"
        "percentage = safe_int(data.get('percentage'))\n"
        "icon = data.get('icon') or ''\n"
        "if icons:\n"
        "  if percentage is not None:\n"
        "    idx = int(percentage * len(icons) / 100)\n"
        "    if idx >= len(icons):\n"
        "      idx = len(icons) - 1\n"
        "    if idx >= 0:\n"
        "      icon = icons[idx]\n"
        "  elif not icon:\n"
        "    icon = icons[0]\n"
        "text = data.get('text','')\n"
        "tooltip = data.get('tooltip','')\n"
        "display = apply_format(fmt, {**data, 'text': text}, icon)\n"
        "payload = {'text': display, 'tooltip': tooltip, 'icon': icon}\n"
        "sys.stdout.write(json.dumps(payload))"
    )

    python_code_escaped = shlex.quote(python_code)
    return (
        f"output=$({exec_cmd}); "
        f"printf '%s' \"$output\" | "
        f"python3 -c {python_code_escaped} {shlex.quote(icons_b64)} {shlex.quote(fmt_b64)}"
    )


def build_python_plain_format(exec_cmd: str, format_str: str) -> str:
    fmt_b64 = base64.b64encode(format_str.encode("utf-8")).decode("ascii")

    python_code = (
        "import base64,sys;"
        "fmt = base64.b64decode(sys.argv[1] or 'e30=').decode('utf-8', 'ignore')\n"
        "raw = sys.stdin.read()\n"
        "raw = raw.rstrip('\n')\n"
        "if not raw:\n"
        "  sys.exit(0)\n"
        "text = raw\n"
        "out = fmt.replace('{}', text).replace('{text}', text)\n"
        "sys.stdout.write(out)"
    )

    python_code_escaped = shlex.quote(python_code)
    return (
        f"output=$({exec_cmd}); "
        f"printf '%s' \"$output\" | "
        f"python3 -c {python_code_escaped} {shlex.quote(fmt_b64)}"
    )


def transform_command(module: WaybarModule) -> TransformResult:
    exec_cmd = module.exec_cmd
    warnings: list[str] = []

    if not exec_cmd:
        return TransformResult(command="", parse_json=False, warnings=warnings)

    format_str = module.format or "{}"
    return_type = module.return_type
    has_format = format_str not in ("{}", "{text}")
    needs_json_wrap = return_type == "json" or module.format_icons or has_format

    if needs_json_wrap and return_type == "json":
        command = build_python_json_transform(exec_cmd, format_str, module.format_icons)
        command = build_exec_if_wrapper(command, module.exec_if)
        return TransformResult(command=command, parse_json=True, warnings=warnings)

    if return_type == "json" and not needs_json_wrap:
        command = build_exec_if_wrapper(exec_cmd, module.exec_if)
        return TransformResult(command=command, parse_json=True, warnings=warnings)

    if has_format:
        command = build_python_plain_format(exec_cmd, format_str)
        command = build_exec_if_wrapper(command, module.exec_if)
        warnings.append("Applied format to plain-text output using python wrapper.")
        return TransformResult(command=command, parse_json=False, warnings=warnings)

    if module.format_icons:
        warnings.append("format-icons provided but return-type is not json; icons cannot be applied.")

    command = build_exec_if_wrapper(exec_cmd, module.exec_if)
    return TransformResult(command=command, parse_json=False, warnings=warnings)


def convert_module_to_widget(
    module: WaybarModule, default_interval: int
) -> tuple[NoctaliaWidgetConfig, list[str]]:
    """Convert a Waybar module to a Noctalia CustomButton configuration."""
    warnings: list[str] = []

    transform = transform_command(module)
    warnings.extend(transform.warnings)

    if module.interval_signal_override:
        warnings.append(
            f"signal provided; polling interval set to {module.interval}s."
        )
    elif module.interval_defaulted:
        warnings.append(
            f"interval not set; defaulting to {default_interval}s (Waybar default)."
        )

    widget = NoctaliaWidgetConfig(textCommand=transform.command)

    if module.interval_mode == "once":
        widget.textStream = True
    else:
        widget.textStream = False
        widget.textIntervalMs = module.interval * 1000 if module.interval else None

    widget.parseJson = transform.parse_json if transform.parse_json else None

    if module.on_click:
        widget.leftClickExec = module.on_click
        if module.exec_on_event:
            widget.leftClickUpdateText = True
    if module.on_click_right:
        widget.rightClickExec = module.on_click_right
        if module.exec_on_event:
            widget.rightClickUpdateText = True
    if module.on_click_middle:
        widget.middleClickExec = module.on_click_middle
        if module.exec_on_event:
            widget.middleClickUpdateText = True

    if module.on_scroll_up:
        widget.wheelUpExec = module.on_scroll_up
    if module.on_scroll_down:
        widget.wheelDownExec = module.on_scroll_down
    if module.on_scroll_up or module.on_scroll_down:
        widget.wheelMode = "separate"
        if module.exec_on_event:
            widget.wheelUpUpdateText = bool(module.on_scroll_up)
            widget.wheelDownUpdateText = bool(module.on_scroll_down)

    if module.max_length:
        widget.maxTextLength = {
            "horizontal": module.max_length,
            "vertical": min(module.max_length, 10),
        }

    if module.restart_interval:
        warnings.append("restart-interval is not supported for CustomButton widgets.")

    return widget, warnings


def escape_qml_string(s: str) -> str:
    """Escape a string for use in QML."""
    return s.replace("\\", "\\\\").replace('"', "\\\"").replace("\n", "\\n")


def render_list_literal(values: list) -> str:
    return json.dumps(values, ensure_ascii=True)


def generate_plugin_scaffold(module: WaybarModule, output_dir: Path, default_interval: int) -> None:
    """Generate a full Noctalia plugin scaffold for a Waybar module."""

    plugin_id = f"waybar-{module.name}"
    plugin_dir = output_dir / "plugins" / plugin_id
    plugin_dir.mkdir(parents=True, exist_ok=True)

    interval_setting = module.interval if module.interval is not None else default_interval

    manifest = {
        "id": plugin_id,
        "name": f"Waybar {module.name.replace('-', ' ').title()}",
        "version": "1.0.0",
        "author": "waybar-converter",
        "description": f"Converted from Waybar custom/{module.name} module",
        "entryPoints": {
            "main": "Main.qml",
            "barWidget": "BarWidget.qml",
            "settings": "Settings.qml",
        },
        "metadata": {
            "defaultSettings": {
                "textCommand": module.exec_cmd,
                "interval": interval_setting,
                "intervalMode": module.interval_mode,
                "restartIntervalMs": (module.restart_interval or 0) * 1000,
                "parseJson": module.return_type == "json",
            }
        },
    }

    with open(plugin_dir / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    format_literal = escape_qml_string(module.format or "{}")
    icons_literal = render_list_literal(module.format_icons)
    exec_if_literal = escape_qml_string(module.exec_if)

    main_qml = f'''import QtQuick
import Quickshell
import Quickshell.Io

Item {{
  id: root

  property var pluginApi: null

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({{}})

  function settingOr(value, fallback) {{
    return (value !== undefined && value !== null) ? value : fallback;
  }}

  readonly property string textCommand: settingOr(pluginApi?.pluginSettings?.textCommand, settingOr(defaultSettings.textCommand, "{escape_qml_string(module.exec_cmd)}"))
  readonly property int intervalSeconds: settingOr(pluginApi?.pluginSettings?.interval, settingOr(defaultSettings.interval, {interval_setting}))
  readonly property string intervalMode: settingOr(pluginApi?.pluginSettings?.intervalMode, settingOr(defaultSettings.intervalMode, "{module.interval_mode}"))
  readonly property int restartIntervalMs: settingOr(pluginApi?.pluginSettings?.restartIntervalMs, settingOr(defaultSettings.restartIntervalMs, 0))
  readonly property bool parseJson: settingOr(pluginApi?.pluginSettings?.parseJson, settingOr(defaultSettings.parseJson, {str(module.return_type == "json").lower()}))

  readonly property string execIf: "{exec_if_literal}"
  readonly property string formatString: "{format_literal}"
  readonly property var formatIcons: {icons_literal}
  readonly property bool escapeMarkup: {str(module.escape).lower()}

  property string displayText: ""
  property string displayIcon: ""
  property string displayTooltip: ""

  readonly property bool isStreaming: intervalMode === "once"

  signal refreshed()

  SplitParser {{
    id: stdoutSplit
    onRead: line => root.parseOutput(line)
  }}

  StdioCollector {{
    id: stdoutCollect
    onStreamFinished: () => root.parseOutput(this.text)
  }}

  StdioCollector {{
    id: stderrCollect
    onStreamFinished: () => {{
      if (this.text && this.text.trim().length > 0) {{
        Logger.w("{plugin_id}", this.text.trim())
      }}
    }}
  }}

  Process {{
    id: textProc
    command: ["sh", "-lc", root.buildCommand()]
    stdout: isStreaming ? stdoutSplit : stdoutCollect
    stderr: stderrCollect
    onExited: (exitCode, exitStatus) => {{
      if (isStreaming && restartIntervalMs > 0) {{
        restartTimer.start();
      }}
    }}
  }}

  Timer {{
    id: pollTimer
    interval: Math.max(250, intervalSeconds * 1000)
    repeat: true
    running: intervalMode === "poll" && textCommand.length > 0
    triggeredOnStart: true
    onTriggered: runCommand()
  }}

  Timer {{
    id: restartTimer
    interval: Math.max(500, restartIntervalMs)
    repeat: false
    onTriggered: runCommand()
  }}

  function buildCommand() {{
    if (!execIf) return textCommand;
    return `if ${{execIf}}; then ${{textCommand}}; fi`;
  }}

  function runCommand() {{
    if (!textCommand || textProc.running) return;
    textProc.running = true;
  }}

  function refresh() {{
    if (intervalMode === "poll") {{
      runCommand();
    }}
  }}

  function pickIcon(data) {{
    var icon = data.icon || "";
    if (!formatIcons || formatIcons.length === 0) return icon;
    var pct = parseInt(data.percentage);
    if (!isNaN(pct)) {{
      var idx = Math.floor(pct * formatIcons.length / 100);
      if (idx >= formatIcons.length) idx = formatIcons.length - 1;
      if (idx < 0) idx = 0;
      icon = formatIcons[idx];
    }} else if (!icon) {{
      icon = formatIcons[0];
    }}
    return icon;
  }}

  function applyFormat(fmt, data, icon) {{
    if (!fmt || fmt === "{{}}" || fmt === "{{text}}") return data.text || "";
    var out = fmt.replace("{{}}", data.text || "");
    var replacements = {{
      "{{text}}": data.text || "",
      "{{icon}}": icon || "",
      "{{percentage}}": data.percentage !== undefined ? String(data.percentage) : "",
      "{{class}}": data.class !== undefined ? String(data.class) : "",
      "{{alt}}": data.alt !== undefined ? String(data.alt) : ""
    }};
    for (var key in replacements) {{
      out = out.split(key).join(replacements[key]);
    }}
    return out;
  }}

  function parseOutput(content) {{
    var raw = String(content || "").trim();
    if (!raw) return;

    if (parseJson) {{
      try {{
        var parsed = JSON.parse(raw);
        var icon = pickIcon(parsed || {{}});
        var display = applyFormat(formatString, parsed || {{}}, icon);
        displayText = display;
        displayIcon = icon;
        displayTooltip = parsed.tooltip || "";
      }} catch (e) {{
        displayText = raw;
        displayIcon = "";
        displayTooltip = raw;
      }}
    }} else {{
      var formatted = applyFormat(formatString, {{ text: raw }}, "");
      displayText = formatted;
      displayIcon = "";
      displayTooltip = raw;
    }}

    refreshed();
  }}

  Component.onCompleted: {{
    if (textCommand.length > 0) {{
      runCommand();
    }}
  }}
}}
'''

    with open(plugin_dir / "Main.qml", "w", encoding="utf-8") as f:
        f.write(main_qml)

    escaped_left = escape_qml_string(module.on_click)
    escaped_right = escape_qml_string(module.on_click_right)
    escaped_middle = escape_qml_string(module.on_click_middle)
    escaped_scroll_up = escape_qml_string(module.on_scroll_up)
    escaped_scroll_down = escape_qml_string(module.on_scroll_down)

    bar_widget_qml = f'''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {{
  id: root

  property var pluginApi: null
  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property string pillText: isBarVertical ? "" : (pluginMain?.displayText || "")
  readonly property string iconName: pluginMain?.displayIcon || ""

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {{
    id: pill

    screen: root.screen
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: pluginMain?.displayTooltip || pluginMain?.displayText || ""
    forceOpen: !isBarVertical && (pluginMain?.displayText || "") !== ""
    onClicked: runDetached("{escaped_left}", {str(module.exec_on_event).lower()})
    onRightClicked: runDetached("{escaped_right}", {str(module.exec_on_event).lower()})
    onMiddleClicked: runDetached("{escaped_middle}", {str(module.exec_on_event).lower()})
  }}

  function runDetached(cmd, shouldRefresh) {{
    if (!cmd) return;
    Quickshell.execDetached(["sh", "-c", cmd]);
    if (shouldRefresh) {{
      pluginMain?.refresh();
    }}
  }}

  function runScroll(cmd, shouldRefresh) {{
    if (!cmd) return;
    Quickshell.execDetached(["sh", "-c", cmd]);
    if (shouldRefresh) {{
      pluginMain?.refresh();
    }}
  }}

  WheelHandler {{
    enabled: true
    onWheel: (event) => {{
      if (event.angleDelta.y > 0) {{
        runScroll("{escaped_scroll_up}", {str(module.exec_on_event).lower()});
      }} else if (event.angleDelta.y < 0) {{
        runScroll("{escaped_scroll_down}", {str(module.exec_on_event).lower()});
      }}
    }}
  }}
}}
'''

    with open(plugin_dir / "BarWidget.qml", "w", encoding="utf-8") as f:
        f.write(bar_widget_qml)

    settings_qml = f'''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.Panels.Settings

Item {{
  id: root

  property var pluginApi: null

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({{}})

  function settingOr(value, fallback) {{
    return (value !== undefined && value !== null) ? value : fallback;
  }}

  property string valueTextCommand: settingOr(pluginApi?.pluginSettings?.textCommand, settingOr(defaultSettings.textCommand, "{escape_qml_string(module.exec_cmd)}"))
  property int valueInterval: settingOr(pluginApi?.pluginSettings?.interval, settingOr(defaultSettings.interval, {interval_setting}))
  property string valueIntervalMode: settingOr(pluginApi?.pluginSettings?.intervalMode, settingOr(defaultSettings.intervalMode, "{module.interval_mode}"))
  property int valueRestartMs: settingOr(pluginApi?.pluginSettings?.restartIntervalMs, settingOr(defaultSettings.restartIntervalMs, 0))
  property bool valueParseJson: settingOr(pluginApi?.pluginSettings?.parseJson, settingOr(defaultSettings.parseJson, {str(module.return_type == "json").lower()}))

  ColumnLayout {{
    anchors.fill: parent
    spacing: 12

    SettingsSection {{
      title: pluginApi?.tr("settings.title") || "Waybar Module"
      description: pluginApi?.tr("settings.description") || "Configure the command and update cadence for this converted module."
    }}

    SettingsTextField {{
      label: pluginApi?.tr("settings.command") || "Text command"
      text: valueTextCommand
      onTextChanged: valueTextCommand = text
    }}

    SettingsRow {{
      label: pluginApi?.tr("settings.interval-mode") || "Interval mode"
      ComboBox {{
        model: ["poll", "once"]
        currentIndex: model.indexOf(valueIntervalMode)
        onCurrentTextChanged: valueIntervalMode = currentText
      }}
    }}

    SettingsRow {{
      label: pluginApi?.tr("settings.interval") || "Poll interval (seconds)"
      SpinBox {{
        from: 1
        to: 86400
        value: valueInterval
        enabled: valueIntervalMode === "poll"
        onValueChanged: valueInterval = value
      }}
    }}

    SettingsRow {{
      label: pluginApi?.tr("settings.restart") || "Restart interval (ms)"
      SpinBox {{
        from: 0
        to: 600000
        value: valueRestartMs
        enabled: valueIntervalMode === "once"
        onValueChanged: valueRestartMs = value
      }}
    }}

    SettingsRow {{
      label: pluginApi?.tr("settings.parse-json") || "Parse JSON"
      Switch {{
        checked: valueParseJson
        onToggled: valueParseJson = checked
      }}
    }}

    SettingsButton {{
      text: pluginApi?.tr("settings.save") || "Save"
      onClicked: {{
        if (!pluginApi) return;
        pluginApi.pluginSettings.textCommand = valueTextCommand;
        pluginApi.pluginSettings.interval = valueInterval;
        pluginApi.pluginSettings.intervalMode = valueIntervalMode;
        pluginApi.pluginSettings.restartIntervalMs = valueRestartMs;
        pluginApi.pluginSettings.parseJson = valueParseJson;
        pluginApi.saveSettings();
        pluginApi.mainInstance?.refresh();
      }}
    }}
  }}
}}
'''

    with open(plugin_dir / "Settings.qml", "w", encoding="utf-8") as f:
        f.write(settings_qml)

    i18n_dir = plugin_dir / "i18n"
    i18n_dir.mkdir(exist_ok=True)

    i18n_en = {
        "title": f"Waybar {module.name.replace('-', ' ').title()}",
        "description": f"Converted from Waybar custom/{module.name}",
        "settings": {
            "title": "Waybar Module",
            "description": "Configure the command and update cadence for this converted module.",
            "command": "Text command",
            "interval-mode": "Interval mode",
            "interval": "Poll interval (seconds)",
            "restart": "Restart interval (ms)",
            "parse-json": "Parse JSON",
            "save": "Save",
        },
    }

    with open(i18n_dir / "en.json", "w", encoding="utf-8") as f:
        json.dump(i18n_en, f, indent=2)

    readme = f"""# {manifest['name']}

Converted from Waybar `custom/{module.name}`.

## Usage

1. Update settings in Noctalia if the command path or interval needs tuning.
2. Add the bar widget through Noctalia settings.

## Notes

- Interval mode `poll` uses a timer, `once` assumes a long-running or signal-driven command.
- Restart interval is only used for `once` mode.
"""

    with open(plugin_dir / "README.md", "w", encoding="utf-8") as f:
        f.write(readme)

    print(f"  Created plugin scaffold: {plugin_dir}")


def generate_widget_configs(
    modules: list[WaybarModule], output_dir: Path, default_interval: int
) -> None:
    """Generate CustomButton widget configurations."""

    output_dir.mkdir(parents=True, exist_ok=True)

    widgets = []
    warnings_by_module: dict[str, list[str]] = {}
    for module in modules:
        widget, warnings = convert_module_to_widget(module, default_interval)
        widgets.append(widget.to_dict())
        if warnings:
            warnings_by_module[module.name] = warnings

    config = {
        "_comment": "Add these widgets to your Noctalia bar configuration",
        "_instructions": [
            "Copy the widgets array entries to your settings.json",
            "Add them to bar.widgets.left, bar.widgets.center, or bar.widgets.right",
        ],
        "widgets": widgets,
    }

    config_path = output_dir / "custom_widgets.json"
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)

    print(f"  Generated widget configs: {config_path}")

    widgets_dir = output_dir / "widgets"
    widgets_dir.mkdir(exist_ok=True)

    for module, widget in zip(modules, widgets):
        widget_path = widgets_dir / f"{module.name}.json"
        with open(widget_path, "w", encoding="utf-8") as f:
            json.dump(widget, f, indent=2)
        print(f"  Generated: {widget_path}")

    if warnings_by_module:
        warnings_path = output_dir / "widget_warnings.json"
        with open(warnings_path, "w", encoding="utf-8") as f:
            json.dump(warnings_by_module, f, indent=2)
        print(f"  Generated warnings: {warnings_path}")


def print_conversion_report(modules: list[WaybarModule], default_interval: int) -> None:
    """Print a report of what was converted and any warnings."""

    print("\n" + "=" * 60)
    print("CONVERSION REPORT")
    print("=" * 60)

    for module in modules:
        print(f"\n[custom/{module.name}] ({module.source})")

        warnings: list[str] = []

        if module.signal:
            warnings.append(f"  - signal: {module.signal} (Noctalia uses polling/streaming instead)")

        if module.interval_signal_override:
            warnings.append(f"  - signal: polling interval set to {module.interval}s")
        elif module.interval_defaulted:
            warnings.append(f"  - interval: defaulted to {default_interval}s (Waybar default)")

        if module.interval_mode == "once":
            warnings.append("  - interval: once (treated as streaming in Noctalia)")

        if module.format != "{}" and module.format != "{text}":
            warnings.append(f"  - format: '{module.format}' (converted via formatter)")

        if module.format_icons:
            warnings.append(f"  - format-icons: {len(module.format_icons)} icons (applied when possible)")

        if module.escape:
            warnings.append("  - escape: true (Pango markup escaping not directly supported)")

        if module.min_length:
            warnings.append(f"  - min-length: {module.min_length} (not directly supported, use CSS/styling)")

        if module.restart_interval:
            warnings.append(f"  - restart-interval: {module.restart_interval} (plugins only)")

        if warnings:
            print("  Warnings:")
            for w in warnings:
                print(w)
        else:
            print("  Status: Full conversion supported")

        print("  Converted:")
        if module.exec_cmd:
            print(f"    exec: {module.exec_cmd[:50]}{'...' if len(module.exec_cmd) > 50 else ''}")
        if module.interval_mode == "poll":
            print(f"    interval: {module.interval}s -> {module.interval * 1000}ms")
        else:
            print("    mode: streaming/once")
        if module.on_click:
            print("    on-click -> leftClickExec")
        if module.on_click_right:
            print("    on-click-right -> rightClickExec")
        if module.on_scroll_up or module.on_scroll_down:
            print("    scroll handlers -> wheelUpExec/wheelDownExec")


def find_waybar_config() -> Optional[Path]:
    """Find the default Waybar config file."""
    search_paths = [
        Path.home() / ".config" / "waybar" / "config",
        Path.home() / ".config" / "waybar" / "config.jsonc",
        Path("/etc/xdg/waybar/config"),
    ]

    for path in search_paths:
        if path.exists():
            return path

    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert Waybar custom modules to Noctalia configurations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Use default waybar config
  %(prog)s ~/.config/waybar/config            # Specify config path
  %(prog)s --mode plugins                     # Generate full plugin scaffolds
  %(prog)s --mode both --output-dir ./output  # Generate both types
        """,
    )

    parser.add_argument(
        "config_path",
        nargs="?",
        help="Path to Waybar config file (default: ~/.config/waybar/config)",
    )

    parser.add_argument(
        "--output-dir",
        "-o",
        default="./waybar-converted",
        help="Output directory for generated files (default: ./waybar-converted)",
    )

    parser.add_argument(
        "--mode",
        "-m",
        choices=["widgets", "plugins", "both"],
        default="widgets",
        help="Output mode: widgets, plugins, or both (default: widgets)",
    )

    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show detailed conversion information",
    )

    parser.add_argument(
        "--default-interval",
        type=int,
        default=DEFAULT_WAYBAR_INTERVAL,
        help="Default interval in seconds when not specified (default: 60)",
    )

    parser.add_argument(
        "--signal-poll-interval",
        type=int,
        default=2,
        help="Polling interval (seconds) to use when a module has signal but no interval (default: 2)",
    )

    args = parser.parse_args()

    if args.config_path:
        config_path = Path(args.config_path)
    else:
        config_path = find_waybar_config()
        if not config_path:
            print("Error: Could not find Waybar config file.")
            print("Please specify the path: waybar_to_noctalia.py /path/to/config")
            sys.exit(1)

    if not config_path.exists():
        print(f"Error: Config file not found: {config_path}")
        sys.exit(1)

    print(f"Reading Waybar config: {config_path}")

    config = parse_waybar_config(config_path)
    modules = extract_custom_modules(
        config, args.default_interval, args.signal_poll_interval
    )

    if not modules:
        print("No custom modules found in Waybar config.")
        sys.exit(0)

    print(f"Found {len(modules)} custom module(s): {', '.join(m.name for m in modules)}")

    output_dir = Path(args.output_dir)

    if args.mode in ["widgets", "both"]:
        print("\nGenerating CustomButton widget configurations...")
        generate_widget_configs(modules, output_dir, args.default_interval)

    if args.mode in ["plugins", "both"]:
        print("\nGenerating plugin scaffolds...")
        for module in modules:
            generate_plugin_scaffold(module, output_dir, args.default_interval)

    if args.verbose:
        print_conversion_report(modules, args.default_interval)

    print("\n" + "=" * 60)
    print("CONVERSION COMPLETE")
    print("=" * 60)
    print(f"\nOutput written to: {output_dir.absolute()}")

    if args.mode in ["widgets", "both"]:
        print("\nTo use CustomButton widgets:")
        print("  1. Review the generated JSON in custom_widgets.json")
        print("  2. Add widgets to your Noctalia settings.json bar configuration")

    if args.mode in ["plugins", "both"]:
        print("\nTo use generated plugins:")
        print("  1. Copy plugin folders to ~/.config/noctalia/plugins/")
        print("  2. Enable them in Noctalia settings")
        print("  3. Add the bar widget to your bar configuration")


if __name__ == "__main__":
    main()
