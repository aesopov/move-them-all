import unittest
from import_uz3 import convert
from audit_uz3 import parse
from test_audit_uz3 import fixture, cell_offset
import struct


def source_cell(data, x, y, flags=b'000000', sprite=b'non', group=0, obstacle=b'0'):
    i = cell_offset(x, y)
    data[i:i+6] = flags
    data[i+14:i+17] = sprite
    data[i+32:i+33] = obstacle
    struct.pack_into('<H', data, i+33, group)
    return i


class ConverterTests(unittest.TestCase):
    def test_source_shapes_and_metadata(self):
        data = fixture()
        source_cell(data, 4, 5, b'110000', b'200', 1)
        result, _ = convert(parse(data, 'LEVEL017.UZ3'), 17)
        item = result['items'][0]
        self.assertEqual((item['x'], item['y'], item['type'], item['match_group']), (4,5,'cube',1))
        self.assertTrue(item['aim'])
        self.assertEqual(item['gravity'], 'none')
        self.assertEqual(result['theme'], 'waterfall')

    def test_world_two_water_and_collision_independent_of_opacity(self):
        data = fixture()
        source_cell(data, 2, 2, b'000010')
        source_cell(data, 3, 2, sprite=b'!10', obstacle=b'1')
        result, _ = convert(parse(data), 17)
        self.assertEqual(result['terrain'][2][2:4], 'w#')

    def test_bomb_source_gravity_and_immovable_falling_entity(self):
        data = fixture()
        source_cell(data, 2, 2, b'111000', b'209', 666)
        source_cell(data, 3, 3, b'100100', b'205', 1)
        result, _ = convert(parse(data), 17)
        self.assertEqual(result['items'][0]['gravity'], 'bubble')
        self.assertFalse(result['items'][0]['aim'])
        self.assertFalse(result['items'][1]['movable'])
        self.assertTrue(result['items'][1]['destructible'])

    def test_bomb_without_source_gravity(self):
        data = fixture()
        source_cell(data, 7, 11, b'110000', b'209', 666)
        result, _ = convert(parse(data), 26)
        self.assertEqual(result['items'][0]['gravity'], 'none')

    def test_pipe_input_codes_and_exact_landing(self):
        # Known source cases: level4 left/right mouths, level8 top entry,
        # level16 bottom entry, double-ended vertical pipe (507).
        for code, sprite, expected in [(1,b'506',['up']), (2,b'506',['down']), (3,b'507',['up','down']), (4,b'504',['left']), (5,b'505',['right'])]:
            data = fixture()
            i = source_cell(data, 4, 4, b'000001', sprite)
            data[i+20:i+22] = f'{code}1'.encode()
            data[i+6], data[i+8] = 8, 7
            result, _ = convert(parse(data), 17)
            route = result['pipes'][0]
            self.assertEqual(route['enter'], expected)
            self.assertEqual(route['to'], [8,7])
            self.assertEqual(route['destination'], 'cell')

    def test_locked_teleport_uses_removable_lock(self):
        data = fixture()
        i = source_cell(data, 5, 2, b'000001', b'403')
        data[i+10] = 2
        data[i+20:i+22] = b'01'
        data[i+6], data[i+8] = 1, 1
        result, _ = convert(parse(data), 50)
        self.assertEqual(result['items'][0]['type'], 'padlock')
        self.assertEqual(result['items'][0]['lock'], 'yellow')
        self.assertEqual(result['teleports'][0]['to'], [1,1])

    def test_locked_visible_object_remains_an_object(self):
        data = fixture()
        i = source_cell(data, 9, 4, sprite=b't09', obstacle=b'1')
        data[i+10] = 3
        result, _ = convert(parse(data), 87)
        self.assertNotEqual(result['items'][0]['type'], 'padlock')
        self.assertEqual(result['items'][0]['lock'], 'green')
        self.assertFalse(result['items'][0]['movable'])

    def test_standalone_lock_over_floor_background(self):
        data = fixture()
        i = source_cell(data, 9, 4)
        data[i+10] = 1
        data[i+17:i+20] = b'116'
        result, _ = convert(parse(data), 17)
        self.assertEqual(result['items'][0]['type'], 'padlock')
        self.assertEqual(result['items'][0]['lock'], 'red')
        self.assertEqual(result['terrain'][4][9], '.')

    def test_arrival_only_portal_is_visible_without_reverse_route(self):
        data = fixture()
        i = source_cell(data, 10, 10, b'000001', b'403')
        data[i+20:i+22] = b'01'
        data[i+6], data[i+8] = 3, 5
        source_cell(data, 3, 5, sprite=b'403')
        result, _ = convert(parse(data), 17)
        self.assertEqual(result['teleports'], [
            dict(x=10, y=10, to=[3,5], strict=True), dict(x=3, y=5)])

    def test_unknown_entry_rejected_not_guessed(self):
        data = fixture()
        i = source_cell(data, 4, 4, b'000001', b'507')
        data[i+20:i+22] = b'71'
        with self.assertRaises(ValueError):
            convert(parse(data), 17)

    def test_alert_boxes_protected_and_non_goal_pairs_retained(self):
        data = fixture()
        i = source_cell(data, 1, 1, b'110000', b'111', 12)
        data[i+22:i+25] = b'021'
        source_cell(data, 2, 1, b'110000', b'120', 11)
        result, _ = convert(parse(data), 17)
        alert, pair = result['items']
        self.assertEqual(alert['type'], 'block_blue')
        self.assertFalse(alert['destructible'])
        self.assertEqual(alert['match_group'], 12)
        self.assertEqual(pair['match_group'], 11)
        self.assertFalse(pair['aim'])


if __name__ == '__main__':
    unittest.main()
