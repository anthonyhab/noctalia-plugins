import json
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import waybar_to_noctalia as converter  # noqa: E402


class JsoncParsingTests(unittest.TestCase):
    def test_strip_jsonc_preserves_strings(self):
        content = r'''
        {
          // comment
          "custom/foo": {
            "exec": "echo 'value,]}'",
            "interval": 5,
          },
        }
        '''
        cleaned = converter.strip_jsonc_comments(content)
        parsed = json.loads(cleaned)
        self.assertIn("custom/foo", parsed)
        self.assertEqual(parsed["custom/foo"]["exec"], "echo 'value,]}'")

    def test_extract_from_array(self):
        config = [
            {"custom/foo": {"exec": "echo 1"}},
            {"custom/bar": {"exec": "echo 2", "interval": "once"}},
        ]
        modules = converter.extract_custom_modules(config, 60, 2)
        names = [module.name for module in modules]
        self.assertEqual(names, ["foo", "bar"])
        self.assertEqual(modules[0].interval, 60)
        self.assertTrue(modules[0].interval_defaulted)
        self.assertEqual(modules[1].interval_mode, "once")

    def test_signal_interval_override(self):
        config = {
            "custom/rec": {
                "exec": "screen-recording.sh",
                "signal": 8,
                "return-type": "json",
            }
        }
        modules = converter.extract_custom_modules(config, 60, 2)
        self.assertEqual(modules[0].interval, 2)
        self.assertTrue(modules[0].interval_signal_override)


class TransformTests(unittest.TestCase):
    def test_json_wrapper_for_format_icons(self):
        module = converter.WaybarModule(
            name="foo",
            source="config",
            exec_cmd="echo '{\"text\":\"x\",\"percentage\":50}'",
            return_type="json",
            format_icons=["a", "b"],
        )
        result = converter.transform_command(module)
        self.assertTrue(result.parse_json)
        self.assertIn("python3 -c", result.command)

    def test_plain_format_wrapper(self):
        module = converter.WaybarModule(
            name="foo",
            source="config",
            exec_cmd="echo 123",
            return_type="",
            format="{text}%",
        )
        result = converter.transform_command(module)
        self.assertFalse(result.parse_json)
        self.assertIn("python3 -c", result.command)


if __name__ == "__main__":
    unittest.main()
