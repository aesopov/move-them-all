import tempfile
import unittest
import zipfile
from pathlib import Path
from build_web import split_plan


class SplitTests(unittest.TestCase):
    def test_partitions_imports_and_preserves_every_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'full.zip'
            contents = {
                'assets/items/themes/desert/plant.png.import': b'path="res://.godot/imported/cactus.ctex"',
                '.godot/imported/cactus.ctex': b'cactus',
                'project.binary': b'project',
                'scripts/game.gdc': b'script',
                'assets/tiles/desert/floor_a.png.import': b'path="res://.godot/imported/floor.ctex"\0',
                '.godot/imported/floor.ctex': b'tile',
                'assets/backgrounds/desert.png.import': b'path="res://.godot/imported/desert.ctex"',
                '.godot/imported/desert.ctex': b'background',
                'assets/backgrounds/menu/waterfall.webp.import': b'path="res://.godot/imported/menu.ctex"',
                '.godot/imported/menu.ctex': b'menu',
            }
            with zipfile.ZipFile(archive, 'w') as z:
                for name, data in contents.items(): z.writestr(name, data)
            plan = split_plan(archive, root / 'files', root / 'output')
            deferred = plan['themes']['desert']['files']
            self.assertEqual(set(plan['base']) | set(deferred), set(contents))
            self.assertFalse(set(plan['base']) & set(deferred))
            self.assertIn('.godot/imported/floor.ctex', deferred)
            self.assertIn('.godot/imported/menu.ctex', plan['base'])
            self.assertEqual(plan['themes']['desert']['assets'], ['backgrounds/desert.png', 'items/themes/desert/plant.png', 'tiles/desert/floor_a.png'])


if __name__ == '__main__': unittest.main()
