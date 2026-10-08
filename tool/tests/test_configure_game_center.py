import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from configure_game_center import configure


class SigningConfigurationTests(unittest.TestCase):
    def test_default_build_preserves_existing_signing(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'project.pbxproj'
            source = Path('ios/Runner.xcodeproj/project.pbxproj').read_text()
            path.write_text(source)
            self.assertFalse(configure(path, ''))
            self.assertEqual(path.read_text(), source)

    def test_optional_feature_enables_all_three_runner_configs_once(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'project.pbxproj'
            source = Path('ios/Runner.xcodeproj/project.pbxproj').read_text()
            path.write_text(source)
            self.assertTrue(configure(path, 'com.systemcraft.busJam.daily'))
            updated = path.read_text()
            self.assertEqual(updated.count('CODE_SIGN_ENTITLEMENTS = Runner/GameCenter.entitlements;'), 3)
            self.assertTrue(configure(path, 'com.systemcraft.busJam.daily'))
            self.assertEqual(path.read_text(), updated)


if __name__ == '__main__':
    unittest.main()
