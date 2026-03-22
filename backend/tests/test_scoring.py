from __future__ import annotations

from io import BytesIO
import math
import wave

import numpy as np

from app.scoring import analyze_pronunciation


def test_scoring_output_stays_in_expected_range_with_reference() -> None:
    user_audio = _sine_wav(440.0)
    ref_audio = _sine_wav(450.0)

    result = analyze_pronunciation(
        target_text="shadow voice",
        user_audio_bytes=user_audio,
        ref_audio_bytes=ref_audio,
    )

    assert 0.0 <= result.overall_score <= 100.0
    assert 1 <= len(result.worst_segments) <= 3
    for segment in result.worst_segments:
        assert 0.0 <= segment.segment_score <= 100.0
        assert segment.start_sec >= 0.0
        assert segment.end_sec > segment.start_sec


def test_scoring_output_stays_in_expected_range_without_reference() -> None:
    result = analyze_pronunciation(
        target_text="shadow voice",
        user_audio_bytes=_sine_wav(440.0),
    )

    assert 0.0 <= result.overall_score <= 100.0
    for segment in result.worst_segments:
        assert 0.0 <= segment.segment_score <= 100.0


def _sine_wav(
    frequency: float,
    duration_sec: float = 1.2,
    sample_rate: int = 16_000,
) -> bytes:
    sample_count = int(duration_sec * sample_rate)
    samples = [
        int(0.5 * 32767 * math.sin(2.0 * math.pi * frequency * index / sample_rate))
        for index in range(sample_count)
    ]
    pcm = np.array(samples, dtype=np.int16)

    buffer = BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm.tobytes())
    return buffer.getvalue()
