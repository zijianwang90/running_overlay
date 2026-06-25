#!/usr/bin/env python3
"""Generate small, synthetic, privacy-safe test fixtures."""

from __future__ import annotations

import struct
from pathlib import Path


FIT_EPOCH_UNIX = 631065600
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Tests/RunningOverlayTests/Fixtures/Activities/synthetic-run.fit"


def definition(local: int, global_message: int, fields: list[tuple[int, int, int]]) -> bytes:
    payload = bytearray([0x40 | local, 0, 0])
    payload.extend(struct.pack("<H", global_message))
    payload.append(len(fields))
    for number, size, base_type in fields:
        payload.extend((number, size, base_type))
    return bytes(payload)


def generate_fit() -> bytes:
    start_unix = 1_735_689_600  # 2025-01-01T00:00:00Z
    start_fit = start_unix - FIT_EPOCH_UNIX

    data = bytearray()

    session_fields = [
        (2, 4, 0x86),   # start_time
        (7, 4, 0x86),   # total_elapsed_time, milliseconds
        (9, 4, 0x86),   # total_distance, centimeters
    ]
    data.extend(definition(0, 18, session_fields))
    data.append(0)
    data.extend(struct.pack("<III", start_fit, 60_000, 20_000))

    record_fields = [
        (253, 4, 0x86),  # timestamp
        (5, 4, 0x86),    # distance
        (6, 2, 0x84),    # speed
        (3, 1, 0x02),    # heart rate
        (2, 2, 0x84),    # altitude
    ]
    data.extend(definition(1, 20, record_fields))

    records = [
        (0, 0, 3_000, 120, 3_000),
        (30, 10_000, 3_250, 145, 3_025),
        (60, 20_000, 3_500, 160, 3_050),
    ]
    for seconds, distance_cm, speed_mm_s, heart_rate, altitude_scaled in records:
        data.append(1)
        data.extend(
            struct.pack(
                "<IIHBH",
                start_fit + seconds,
                distance_cm,
                speed_mm_s,
                heart_rate,
                altitude_scaled,
            )
        )

    header = bytearray()
    header.extend((14, 0x10))
    header.extend(struct.pack("<H", 0))
    header.extend(struct.pack("<I", len(data)))
    header.extend(b".FIT")
    header.extend(b"\x00\x00")
    return bytes(header + data)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(generate_fit())
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
