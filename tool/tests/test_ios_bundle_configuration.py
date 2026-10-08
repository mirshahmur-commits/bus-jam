"""Check Apple's orientation rule before attempting an App Store upload."""

import plistlib
import unittest
from pathlib import Path


class IOSBundleConfigurationTests(unittest.TestCase):
    def test_ipad_multitasking_requires_all_interface_orientations(self):
        root = Path(__file__).resolve().parents[2]
        with (root / "ios/Runner/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        orientations = set(
            info.get(
                "UISupportedInterfaceOrientations~ipad",
                info.get("UISupportedInterfaceOrientations", []),
            )
        )
        required = {
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        }
        self.assertTrue(
            info.get("UIRequiresFullScreen") is True
            or required.issubset(orientations),
            "Apple ITMS-90474: iPad multitasking requires all four orientations; "
            "a portrait-only game must explicitly require full screen.",
        )


if __name__ == "__main__":
    unittest.main()
