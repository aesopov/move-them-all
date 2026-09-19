"""Synthetic binary cases; no original game files required."""
import struct
import unittest
from audit_uz3 import GRID_OFFSET, GRID_END, CELL_SIZE, parse, audit


def fixture():
    data = bytearray(GRID_END + 2)
    struct.pack_into('<H', data, 0, 4)
    data[2:6] = b'Test'
    for c in range(144):
        start = GRID_OFFSET + c * CELL_SIZE
        data[start:start + 6] = b'000000'
        data[start + 14:start + 20] = b'nonnon'
        data[start + 22:start + 28] = b'nonnon'
        data[start + 32] = ord('0')
    return data


def cell_offset(x, y):
    return GRID_OFFSET + (x * 12 + y) * CELL_SIZE


class ParserTests(unittest.TestCase):
    def test_column_major_flags_and_lock_color_ids(self):
        data = fixture()
        start = cell_offset(2, 7)
        data[start:start + 6] = b'110101'
        data[start + 6], data[start + 8] = 10, 3
        data[start + 10], data[start + 12] = 2, 3
        data[start + 14:start + 17] = b'205'
        struct.pack_into('<H', data, start + 33, 666)
        parsed = parse(data)
        cell = parsed['cells'][7 * 12 + 2]
        self.assertEqual((cell['x'], cell['y'], cell['pieceId']), (2, 7, 666))
        self.assertTrue(cell['falls'] and cell['teleport'] and cell['movable'])
        self.assertEqual((cell['teleX'], cell['teleY']), (10, 3))
        self.assertEqual((cell['lock'], cell['key']), (2, 3))
        reconstructed = bytes.fromhex(parsed['header_hex']) + b''.join(
            bytes.fromhex(c['raw_hex']) for c in sorted(parsed['cells'], key=lambda c: c['offset'])
        ) + bytes.fromhex(parsed['trailer_hex'])
        self.assertEqual(reconstructed, data)

    def test_truncation_and_bad_name_rejected(self):
        with self.assertRaises(ValueError):
            parse(fixture()[:GRID_END - 1])
        data = fixture()
        struct.pack_into('<H', data, 0, 65535)
        with self.assertRaises(ValueError):
            parse(data)

    def test_translucency_does_not_determine_collision(self):
        data = fixture()
        start = cell_offset(3, 4)
        data[start + 14:start + 17] = b'!10'
        data[start + 32] = ord('1')
        level = parse(data)
        self.assertEqual(level['cells'][4 * 12 + 3]['obstacle'], '1')
        manual = dict(items=[], terrain=['.' * 12] * 12)
        self.assertIn([3, 4], audit(level, manual)['manual_comparison']['static_collision_differences'])

    def test_appearance_and_matching_are_independent(self):
        data = fixture()
        for x, sprite, group in [(0, b'200', 1), (1, b'200', 2), (2, b'201', 1)]:
            start = cell_offset(x, 0)
            data[start:start + 6] = b'110000'
            data[start + 14:start + 17] = sprite
            struct.pack_into('<H', data, start + 33, group)
        matching = audit(parse(data))['matching']
        self.assertEqual(matching['same_sprite_different_groups'], {'200': [1, 2]})
        self.assertEqual(matching['same_group_different_sprites'], {'1': ['200', '201']})


if __name__ == '__main__':
    unittest.main()
