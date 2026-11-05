"""Behavioral checks; never touch the real LibreOffice profile or launch applications."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("settings", ROOT / "scripts/lo-settings.py")
lo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lo)


def xcu(path, prop, value):
    root = ET.Element(f"{{{lo.OOR}}}items")
    item = ET.SubElement(root, "item", {f"{{{lo.OOR}}}path": path})
    prop = ET.SubElement(item, "prop", {f"{{{lo.OOR}}}name": prop})
    ET.SubElement(prop, "value").text = value
    return root


class SettingsTests(unittest.TestCase):
    def test_native_profile_locations(self):
        home = Path("/test/home")
        self.assertEqual(lo.profile_path("Darwin", {}, home), home / "Library/Application Support/LibreOffice/4/user")
        self.assertEqual(lo.profile_path("Linux", {"XDG_CONFIG_HOME": "/xdg"}, home), Path("/xdg/libreoffice/4/user"))
        self.assertEqual(lo.profile_path("Linux", {}, home), home / ".config/libreoffice/4/user")
        self.assertEqual(lo.profile_path("Windows", {"APPDATA": "/roaming"}, home), Path("/roaming/LibreOffice/4/user"))
        with self.assertRaises(RuntimeError):
            lo.profile_path("Windows", {}, home)

    def test_running_process_detection_has_no_shell_false_positive(self):
        names = ["/Applications/LibreOffice.app/Contents/MacOS/soffice", "soffice.bin", "SOFFICE.EXE", "unopkg.com", "python lo-settings.py", "zsh -c soffice", "soffice-test"]
        self.assertEqual(lo.office_processes(names), names[:4])

    def test_merge_preserves_private_and_recovery_state(self):
        live = xcu("/org.openoffice.UserProfile/Data", "givenname", "Private Name")
        live.extend(xcu("/org.openoffice.Office.Recovery/RecoveryList", "secret", "unsaved document"))
        live.extend(xcu("/settings", "theme", "old"))
        portable = xcu("/settings", "theme", "new")
        result = lo.merge_xcu(live, portable)
        self.assertEqual([v.text for v in result.iter("value")], ["Private Name", "unsaved document", "new"])
        self.assertEqual(lo.xml_bytes(lo.merge_xcu(result, portable)), lo.xml_bytes(result))

    def test_gpu_selection_is_removed_but_rendering_preferences_remain(self):
        live = xcu("/org.openoffice.Office.Common/Misc", "SelectedOpenCLDeviceIdentifier", "Windows GPU")
        live.extend(xcu("/org.openoffice.Office.Common/Misc", "UseOpenCL", "false"))
        self.assertEqual(len(lo.merge_xcu(live, ET.Element(f"{{{lo.OOR}}}items"))), 1)

    def test_portable_rejects_private_data_and_macros(self):
        for path, prop, value in [
            ("/org.openoffice.UserProfile/Data", "name", "private"),
            ("/org.openoffice.Office.Recovery/RecoveryList", "path", "secret"),
            ("/settings", "path", "file:///private/document"),
            ("/settings", "path", "C:\\Users\\Person\\file"),
            ("/org.openoffice.Office.Accelerators/PrimaryKeys/Global", "key", "macro://private/script"),
        ]:
            with self.subTest(path=path, value=value), self.assertRaises(ValueError):
                lo.portable_check(xcu(path, prop, value))
        lo.portable_check(xcu("/org.openoffice.Office.Recovery/AutoSave", "TimeIntervall", "5"))

    def test_canonical_xml_is_portable(self):
        lo.portable_check(lo.read_xcu(lo.SOURCE))

    def test_apply_refuses_to_write_while_open(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(lo, "office_processes", return_value=["soffice"]):
            profile = Path(temp) / "user"
            with self.assertRaises(RuntimeError):
                lo.apply_settings(profile)
            self.assertFalse(profile.exists())

    def test_export_excludes_unknown_private_settings(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(lo, "require_closed"), patch("sys.stdout", new_callable=io.StringIO):
            root = Path(temp)
            source = root / "settings/registrymodifications.portable.xcu"
            profile = root / "profile/user"
            lo.atomic_write(source, lo.xml_bytes(xcu("/settings", "theme", "old")))
            live = xcu("/settings", "theme", "new")
            live.extend(xcu("/org.openoffice.UserProfile/Data", "name", "private"))
            lo.atomic_write(profile / "registrymodifications.xcu", lo.xml_bytes(live))
            with patch.object(lo, "ROOT", root), patch.object(lo, "SOURCE", source):
                lo.export_settings(profile)
            self.assertEqual([v.text for v in lo.read_xcu(source).iter("value")], ["new"])
            self.assertEqual(len(list(root.glob(".local/backups/*/backup.json"))), 1)

    def test_failed_extension_install_restores_original_registry(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(lo, "office_processes", return_value=[]):
            root = Path(temp)
            profile = root / "profile/user"
            target = profile / "registrymodifications.xcu"
            original = lo.xml_bytes(xcu("/private", "state", "keep"))
            lo.atomic_write(target, original)
            def failure(*args, **kwargs):
                target.write_bytes(lo.xml_bytes(xcu("/wrong", "state", "partial")))
                raise subprocess.CalledProcessError(1, "unopkg")
            with patch.object(lo, "ROOT", root), patch.object(lo, "find_program", return_value=Path("unopkg")), patch.object(subprocess, "run", side_effect=failure):
                lo.atomic_write(root / "settings/side-essentials.xml", (ROOT / "settings/side-essentials.xml").read_bytes())
                with self.assertRaises(RuntimeError):
                    lo.apply_settings(profile)
            self.assertEqual(target.read_bytes(), original)

    def test_document_arguments_are_uris_not_shell_commands(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(lo, "find_program", return_value=Path("/app/soffice")), patch.object(subprocess, "Popen") as launch:
            document = Path(temp) / "-name $() ' عربي test.docx"
            document.touch()
            lo.open_files([str(document)])
            self.assertEqual(launch.call_args.args[0], [str(Path("/app/soffice")), "--nologo", document.resolve().as_uri()])
            self.assertNotIn("shell", launch.call_args.kwargs)
            with self.assertRaises(ValueError):
                lo.open_files([temp])

    def test_rollback_requires_a_local_backup(self):
        with patch.object(lo, "require_closed"), self.assertRaises(ValueError):
            lo.rollback(Path("/untrusted/backup"))

    def test_xml_type_namespaces_survive(self):
        root = xcu("/settings", "type", "hello")
        root[0][0].set(f"{{{lo.OOR}}}type", "xs:string")
        self.assertIn(b'xmlns:xs="http://www.w3.org/2001/XMLSchema"', lo.xml_bytes(root))
        ET.fromstring(lo.xml_bytes(root))

    def test_old_hidden_sidebar_migrates_without_touching_other_windows(self):
        live = xcu("/org.openoffice.Office.UI.Sidebar/Content/DeckList/old", "ContextList", "hidden")
        live.extend(xcu("/org.openoffice.Office.Views/Windows/WindowType['swriter/10336']/UserData", "Data", "V2,H,0"))
        live.extend(xcu("/org.openoffice.Office.Views/Windows/WindowType['other']", "Data", "keep"))
        result = lo.merge_xcu(live, ET.Element(f"{{{lo.OOR}}}items"))
        self.assertEqual([v.text for v in result.iter("value")], ["keep"])

    def test_extension_matches_source_and_does_not_lock_controls(self):
        with zipfile.ZipFile(lo.POLICY) as archive:
            self.assertIsNone(archive.testzip())
            for name in archive.namelist():
                if name.endswith("/"):
                    continue
                self.assertEqual(archive.read(name), (ROOT / "extension/clean-ui" / name).read_bytes())
                if name.endswith(".xcu"):
                    self.assertNotIn(b'oor:finalized="true"', archive.read(name))

    def test_side_layout_and_search_bridges(self):
        registry = lo.read_xcu(lo.SOURCE)
        key_names = {node.get(f"{{{lo.OOR}}}name") for item in registry
                     if ".Accelerators/" in item.get(f"{{{lo.OOR}}}path", "") for node in item}
        self.assertTrue({"F13_MOD1_MOD2", "F14_MOD1_MOD2"} <= key_names)
        self.assertFalse({"F13", "F14"} & key_names)
        for component in ("Writer", "Calc", "Impress", "Draw"):
            items = [item for item in registry if f".{component}WindowState/" in item.get(f"{{{lo.OOR}}}path", "")]
            nodes = [node for item in items for node in item if node.get(f"{{{lo.OOR}}}name") == "private:resource/toolbar/custom_sideessentials"]
            self.assertEqual(len(nodes), 1)
            values = {p.get(f"{{{lo.OOR}}}name"): p.findtext("value") for p in nodes[0]}
            self.assertEqual(values["DockingArea"], "2")
            self.assertEqual(values["Visible"], "true")

    def test_mac_additions_cannot_capture_normal_typing_or_other_apps(self):
        data = json.loads((ROOT / "macos/vim-navigation.json").read_text())
        for rule in data["rules"][0]["manipulators"]:
            self.assertIn({"type": "variable_if", "name": "shk_caps", "value": 1}, rule["conditions"])
            self.assertIn({"type": "frontmost_application_if", "bundle_identifiers": [r"^org\.libreoffice\.script$"]}, rule["conditions"])
            for action in rule["to"]:
                self.assertNotIn("shell_command", action)
                self.assertNotIn(action["key_code"], ("delete_or_backspace", "delete_forward", "q"))

    def test_fresh_mac_profile_has_a_self_contained_scoped_hold_layer(self):
        spec = importlib.util.spec_from_file_location("vim_installer", ROOT / "scripts/install-vim-macos.py")
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        base = json.loads((ROOT / "macos/vim-navigation.json").read_text())["rules"][0]
        standalone = installer.standalone_rule(base)
        self.assertEqual(standalone["manipulators"][0]["to_if_alone"], [{"key_code": "escape"}])
        self.assertEqual(standalone["manipulators"][0]["to_after_key_up"], [{"set_variable": {"name": "lo_caps", "value": 0}}])
        for mapping in standalone["manipulators"][1:]:
            self.assertIn({"type": "variable_if", "name": "lo_caps", "value": 1}, mapping["conditions"])
        self.assertTrue({"h", "j", "k", "l", "w", "e"} <= {m["from"]["key_code"] for m in standalone["manipulators"]})


if __name__ == "__main__":
    unittest.main()
