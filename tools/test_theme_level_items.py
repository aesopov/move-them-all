import copy
import json
from pathlib import Path
import unittest
from theme_level_items import apply, REPLACEMENTS


class ThemeItemsTest(unittest.TestCase):
    def test_preserves_overrides_and_matching(self):
        for theme, mapping in REPLACEMENTS.items():
            for source, target in mapping.items():
                level = {'theme': theme, 'items': [dict(type=source, x=2, y=3,
                         gravity='fall', movable=False, destructible=True,
                         aim=True, match_group=7, match_label='7', lock='red')]}
                expected = copy.deepcopy(level)
                expected['items'][0]['type'] = target
                self.assertEqual(apply(level), expected)
                self.assertEqual(apply(level), expected)  # safe to run again

    def test_campaign_uses_both_world_objects(self):
        for world in sorted(Path('levels').glob('world_*')):
            types = {i['type'] for p in world.glob('*.json')
                     for i in json.loads(p.read_text())['items']}
            self.assertTrue({'cube', 'crystal'} <= types, world)
