"""xfer_on_sm: the read-first loop, the timeout and the interrupt path, against a FIFO model of the
PIO master (no timing). The closed-loop tests in test_cosim.py check the timing."""

import pytest

import polyglot as pg


class FifoMaster(object):
    """A stand-in for the PIO master's FIFOs. It consumes the header and then one TX word per byte,
    and pushes one RX word per byte, after a configurable number of `ticks` per byte. Pushes to a
    full RX FIFO are counted as overflows (the real master would stall with SCK high)."""

    def __init__(self, stall=False, byte_ticks=1):
        self.tx = []
        self.rx = []
        self.stall = stall  # never consume: models a frame that does not run
        self.byte_ticks = byte_ticks
        self.header = None
        self.pending = []  # (byte) consumed but not yet pushed to RX
        self.frame = []  # bytes clocked out in this frame (the MISO value is 0xA0 + index)
        self.overflow = 0
        self.cs_low = False
        self.calls = 0

    def _run(self):
        if self.stall:
            return
        # Consume TX words as the PIO would, and produce RX words.
        while self.tx:
            w = self.tx.pop(0)
            if self.header is None:
                self.header = w
                self.cs_low = True
                continue
            byte = (w >> 24) & 0xFF
            self.frame.append(byte)
            if len(self.rx) >= 4:
                self.overflow += 1
            else:
                self.rx.append(0xA0 + len(self.frame) - 1)
            if self.header is not None and len(self.frame) == self.header + 1:
                self.cs_low = False
                self.header = None
                self.frame = []

    def put(self, v):
        assert len(self.tx) < 4, "put into a full TX FIFO"
        self.tx.append(v)
        self._run()

    def get(self):
        assert self.rx, "get from an empty RX FIFO"
        return self.rx.pop(0)

    def tx_fifo(self):
        self.calls += 1
        self._run()
        return len(self.tx)

    def rx_fifo(self):
        self.calls += 1
        self._run()
        return len(self.rx)


def test_read_first_loop_returns_one_byte_per_byte_sent():
    m = FifoMaster()
    out = pg.xfer_on_sm(m, bytes([1, 2, 3, 4, 5]))
    assert out == bytes([0xA0, 0xA1, 0xA2, 0xA3, 0xA4])
    assert m.overflow == 0


def test_rx_never_overflows_even_with_a_slow_host():
    # The model drops words into a 4-deep RX FIFO. Popping first keeps it at 4 or fewer.
    m = FifoMaster()
    data = bytes(range(16))
    out = pg.xfer_on_sm(m, data)
    assert len(out) == 16
    assert m.overflow == 0


def test_timeout_completes_the_frame_with_zeros_and_raises():
    # A master that never runs: the loop times out. The library pushes zeros so that a running
    # master would finish the frame and release CS_N; here it raises OSError after its spins.
    m = FifoMaster(stall=True)
    now = [0]

    def clock():
        now[0] += 1000
        return now[0]

    with pytest.raises(OSError):
        pg.xfer_on_sm(m, bytes([7, 8]), timeout_us=5000, clock=(clock, lambda a, b: a - b))


def test_interrupt_completes_the_frame_and_reraises():
    class Interrupted(FifoMaster):
        def rx_fifo(self):
            self.calls += 1
            if self.calls == 4:  # one Ctrl-C, during the transfer; the cleanup calls go through
                raise KeyboardInterrupt()
            return super().rx_fifo()

    m = Interrupted()
    with pytest.raises(KeyboardInterrupt):
        pg.xfer_on_sm(m, bytes([1, 2, 3, 4]))
    # The frame was finished with zero bytes: the header and all four bytes went out.
    assert m.header is None and not m.tx


def test_empty_data_is_no_frame():
    m = FifoMaster()
    assert pg.xfer_on_sm(m, b"") == b""
    assert m.tx == []


def test_header_is_n_minus_one():
    m = FifoMaster()
    pg.xfer_on_sm(m, bytes([9, 9, 9]))
    # The header went out first with N-1 = 2; this checks the value the master counts.
    m2 = FifoMaster()
    m2.put = lambda v, _orig=m2.put: (_orig(v))
    seen = []

    class Record(FifoMaster):
        def put(self, v):
            seen.append(v)
            super().put(v)

    r = Record()
    pg.xfer_on_sm(r, bytes([1, 2, 3]))
    assert seen[0] == 2
    assert [(w >> 24) for w in seen[1:]] == [1, 2, 3]


class CountingStuck(FifoMaster):
    """A master that never runs; counts every FIFO call so the test can bound the work."""

    def __init__(self):
        super().__init__(stall=True)
        self.total = 0

    def tx_fifo(self):
        self.total += 1
        return super().tx_fifo()

    def rx_fifo(self):
        self.total += 1
        return super().rx_fifo()

    def put(self, v):
        self.total += 1
        self.tx.append(v)


def test_stuck_master_timeout_does_small_bounded_work():
    # Each clock read advances 1 ms. timeout is 20 ms, so the loop runs about 20 times; the
    # completion is bounded by FINISH_LIMIT_US (10 ms) and runs once. The old code ran a million
    # spins on each of two calls (about 4 million API calls at this timeout).
    m = CountingStuck()
    now = [0]

    def clock():
        now[0] += 1000
        return now[0]

    with pytest.raises(OSError):
        pg.xfer_on_sm(m, bytes([7, 8, 9]), timeout_us=20000, clock=(clock, lambda a, b: a - b))
    assert m.total < 200, m.total


def test_interrupt_with_a_stuck_master_is_bounded_too():
    m = CountingStuck()
    now = [0]

    def clock():
        now[0] += 1000
        return now[0]

    class Ctrl(CountingStuck):
        def __init__(self):
            super().__init__()
            self.rxcalls = 0

        def rx_fifo(self):
            self.total += 1
            self.rxcalls += 1
            if self.rxcalls == 5:
                raise KeyboardInterrupt()
            return FifoMaster.rx_fifo(self)

    m = Ctrl()
    with pytest.raises(KeyboardInterrupt):
        pg.xfer_on_sm(m, bytes([1, 2]), timeout_us=10**9, clock=(clock, lambda a, b: a - b))
    assert m.total < 200, m.total
