"""Frame bytes against chip.md section 6.3, byte for byte, and the frame API errors."""

import pytest

import polyglot as pg


def test_write_one_word_at_zero():
    # CMD 0x00 (R=0, F=0), ADDR 0x0000, then the word MSB first.
    assert pg.frame_write(0x000, [0x12345678]) == bytes([0x00, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78])


def test_write_burst_auto_increments_by_nothing_in_the_bytes():
    # Burst: the addresses are implied by the chip; the bytes are just the words in order.
    b = pg.frame_write(0x040, [0x01020304, 0xA0B0C0D0])
    assert b == bytes([0x00, 0x00, 0x40, 1, 2, 3, 4, 0xA0, 0xB0, 0xC0, 0xD0])


def test_write_fixed_sets_cmd_bit_6():
    # F = CMD[6] = 0x40. R = CMD[7] stays 0.
    b = pg.frame_write(0x050, [0xDEADBEEF, 0x0F0F0F0F], fixed=True)
    assert b[0] == 0x40
    assert b[1:3] == bytes([0x00, 0x50])
    assert b[3:] == bytes([0xDE, 0xAD, 0xBE, 0xEF, 0x0F, 0x0F, 0x0F, 0x0F])


def test_write_address_high_byte():
    b = pg.frame_write(0xFFFC, [1])
    assert b == bytes([0x00, 0xFF, 0xFC, 0, 0, 0, 1])


def test_read_one_word_has_cmd_addr_dummy_then_four_clock_bytes():
    b = pg.frame_read(0x000, 1)
    # CMD = 0x80 (R=1). ADDR = 0x0000. Byte 3 is the dummy byte. Then 4 bytes that clock word 0.
    assert b == bytes([0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    assert len(b) == 4 + 4 * 1


def test_read_fixed_burst_length_and_cmd():
    b = pg.frame_read(0x050, 3, fixed=True)
    assert b[0] == 0xC0  # R=1 and F=1
    assert b[1:4] == bytes([0x00, 0x50, 0x00])
    assert len(b) == 4 + 4 * 3
    assert b[4:] == bytes(12)  # MOSI is ignored in the data bytes: zeros are sent


def test_read_address_bits_0_and_1_must_be_zero():
    with pytest.raises(ValueError):
        pg.frame_read(0x002, 1)
    with pytest.raises(ValueError):
        pg.frame_write(0x003, [0])


def test_write_address_range():
    with pytest.raises(ValueError):
        pg.frame_write(-4, [0])
    with pytest.raises(ValueError):
        pg.frame_write(0x10000, [0])


def test_word_range():
    with pytest.raises(ValueError):
        pg.frame_write(0x038, [0x1_0000_0000])
    with pytest.raises(ValueError):
        pg.frame_write(0x038, [-1])


def test_read_needs_a_word():
    with pytest.raises(ValueError):
        pg.frame_read(0x000, 0)


def test_parse_read_skips_the_dummy_byte_and_is_big_endian():
    # 4 bytes of status and dummy (MISO during the command, address and dummy bytes), then data.
    reply = bytes([0xA0, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0xFF, 0xEE, 0xDD, 0xCC])
    assert pg.frame_parse_read(reply, 2) == [0x01020304, 0xFFEEDDCC]


def test_parse_read_wrong_length():
    with pytest.raises(ValueError):
        pg.frame_parse_read(bytes(8), 2)


def test_status_is_a_one_byte_frame():
    assert pg.frame_status() == bytes([0x00])


def test_status_fields_bit_layout():
    # STATUS = {TXNFULL[3:0], RXNEMPTY[3:0]}: bit 7 is TXNFULL[3], bit 0 is RXNEMPTY[0].
    s = pg.status_fields(0x81)
    assert s["rx_nonempty"] == [1, 0, 0, 0]
    assert s["tx_nonfull"] == [0, 0, 0, 1]
    s = pg.status_fields(0x0F)
    assert s["rx_nonempty"] == [1, 1, 1, 1]
    assert s["tx_nonfull"] == [0, 0, 0, 0]


def test_chip_write_and_read_use_the_frames(tmp_path):
    # Chip.write / read / status send exactly these bytes. A recording transport checks it.
    from test_chip import RecordingTransport

    t = RecordingTransport()
    chip = pg.Chip(t)
    chip.write(0x038, [0xCAFE0001])
    assert t.sent[-1] == bytes([0x00, 0x00, 0x38, 0xCA, 0xFE, 0x00, 0x01])
    t.replies.append(bytes([0, 0, 0, 0, 0x50, 0x4C, 0x47, 0x54]))
    assert chip.read(0x000, 1) == [0x504C4754]
    assert t.sent[-1] == bytes([0x80, 0x00, 0x00, 0x00, 0, 0, 0, 0])
    t.replies.append(bytes([0xB5]))
    assert chip.status() == 0xB5
    assert t.sent[-1] == bytes([0x00])
