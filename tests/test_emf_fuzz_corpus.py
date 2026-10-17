"""Check corpus framing so malformed records are not hidden by a bad header."""
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

GENERATOR = Path(__file__).parent / 'fuzz' / 'gen_emf_corpus.py'
SPEC = importlib.util.spec_from_file_location('emf_fuzz_generator', GENERATOR)
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


class EmfFuzzCorpusTests(unittest.TestCase):
    def test_header_describes_complete_stream(self):
        parts = [GEN.rec(17, struct.pack('<I', 1)),
                 GEN.rec(14, struct.pack('<III', 0, 0, 20))]
        header = GEN.header(parts, 3)
        self.assertEqual(struct.unpack_from('<II', header, 48),
                         (108 + sum(map(len, parts)), 3))
        self.assertEqual(struct.unpack_from('<II', header, 88), (0, 0))
        self.assertEqual(struct.unpack_from('<2i', header, 100), (67000, 67000))

    def test_mutations_are_repeatable(self):
        self.assertEqual(list(GEN.variants('EMR_EXTTEXTOUTW', 84)),
                         list(GEN.variants('EMR_EXTTEXTOUTW', 84)))
        declarations = [struct.unpack_from('<I', data, 4)[0]
                        for _, data in GEN.variants('EMR_EXTTEXTOUTW', 84)]
        self.assertIn(4, declarations)
        self.assertIn(9, declarations)
        self.assertIn(0xfffffff0, declarations)

    def test_full_corpus_has_2100_unique_files_and_valid_envelopes(self):
        with tempfile.TemporaryDirectory(prefix='emf-fuzz-corpus-') as directory:
            subprocess.run([sys.executable, str(GENERATOR), '--out', directory],
                           check=True, capture_output=True)
            output = Path(directory)
            manifest = json.loads((output / 'manifest.json').read_text())
            entries = manifest['files']
            names = {entry['file'] for entry in entries}
            self.assertEqual(len(entries), 2100)
            self.assertEqual(len(names), 2100)
            self.assertEqual({p.name for p in output.glob('*.emf')}, names)
            for entry in entries:
                data = (output / entry['file']).read_bytes()
                self.assertEqual(struct.unpack_from('<II', data), (1, 108))
                self.assertEqual(struct.unpack_from('<II', data, 48), (len(data), 3))
                self.assertEqual(len(data), entry['size'])
                self.assertEqual(struct.unpack_from('<IIIII', data, len(data)-20),
                                 (14, 20, 0, 0, 20))


if __name__ == '__main__':
    unittest.main()
