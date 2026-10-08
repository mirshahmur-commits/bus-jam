"""Enable the optional entitlement only for an explicitly configured build."""
import os
from pathlib import Path


def configure(project: Path, leaderboard: str) -> bool:
    if not leaderboard:
        return False
    source = project.read_text()
    marker = 'PRODUCT_BUNDLE_IDENTIFIER = com.systemcraft.busJam;'
    if 'CODE_SIGN_ENTITLEMENTS = Runner/GameCenter.entitlements;' not in source:
        if source.count(marker) != 3:
            raise ValueError('Expected three Runner build configurations')
        source = source.replace(marker, marker + '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/GameCenter.entitlements;')
        project.write_text(source)
    return True


if __name__ == '__main__':
    enabled = configure(Path('ios/Runner.xcodeproj/project.pbxproj'), os.environ.get('GAME_CENTER_LEADERBOARD_ID', ''))
    print('Game Center configured.' if enabled else 'Using personal records for this build.')
