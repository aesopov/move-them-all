import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from build_yandex import package

class YandexPackageTests(unittest.TestCase):
    def test_required_worklets_relative_packs_and_sdk_gate(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'source'
            source.mkdir()
            (source/'packs').mkdir()
            for name in ['index.js','index.wasm','index.pck','index.audio.worklet.js','index.audio.position.worklet.js','packs/garden-abc.pck']:
                (source/name).write_bytes(b'test')
            (source/'index.pck.gz').write_bytes(b'duplicate')
            (source/'index.html').write_text('<head></head><script>engine.startGame({}).then(() => {});</script>')
            (source/'asset_packs.json').write_text(json.dumps({'themes':{'garden':{'file':'packs/garden-abc.pck'}}}))
            output=Path(temp)/'release/game.zip'
            package(source,output)
            with zipfile.ZipFile(output) as archive:
                self.assertIn('index.audio.worklet.js',archive.namelist())
                self.assertIn('index.audio.position.worklet.js',archive.namelist())
                self.assertIn('packs/garden-abc.pck',archive.namelist())
                self.assertNotIn('index.pck.gz',archive.namelist())
                html=archive.read('index.html').decode()
                self.assertIn('src="/sdk.js"',html)
                self.assertIn('window.mergeYandexReady.then(() => engine.startGame',html)

if __name__=='__main__': unittest.main()
