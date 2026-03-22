from __future__ import annotations

import base64
import binascii
import wave
from dataclasses import dataclass
from io import BytesIO

import numpy as np

TARGET_SAMPLE_RATE = 16_000


class AudioDecodeError(ValueError):
    """Raised when the request audio cannot be decoded as WAV."""


@dataclass(frozen=True)
class AudioBuffer:
    samples: np.ndarray
    sample_rate: int

    @property
    def duration_sec(self) -> float:
        if self.sample_rate <= 0:
            return 0.0
        return float(len(self.samples) / self.sample_rate)


def decode_base64_audio(audio_b64: str) -> bytes:
    payload = audio_b64.strip()
    if "," in payload and payload.lower().startswith("data:"):
        payload = payload.split(",", 1)[1]

    try:
        return base64.b64decode(payload, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise AudioDecodeError("Audio must be valid base64-encoded WAV bytes.") from exc


def load_wav_mono(audio_bytes: bytes) -> AudioBuffer:
    if not audio_bytes:
        raise AudioDecodeError("Audio payload is empty.")

    try:
        with wave.open(BytesIO(audio_bytes), "rb") as wav_file:
            sample_rate = wav_file.getframerate()
            channels = wav_file.getnchannels()
            sample_width = wav_file.getsampwidth()
            frame_count = wav_file.getnframes()
            raw_frames = wav_file.readframes(frame_count)
    except (wave.Error, EOFError) as exc:
        raise AudioDecodeError("Audio must be a valid WAV file.") from exc

    if frame_count == 0:
        raise AudioDecodeError("WAV file does not contain any samples.")
    if channels <= 0 or sample_rate <= 0:
        raise AudioDecodeError("WAV metadata is invalid.")

    samples = _pcm_to_float(raw_frames, sample_width)
    samples = samples.reshape(-1, channels).mean(axis=1).astype(np.float32, copy=False)

    peak = float(np.max(np.abs(samples)))
    if peak > 0:
        samples = samples / peak

    return AudioBuffer(samples=samples, sample_rate=sample_rate)


def ensure_sample_rate(buffer: AudioBuffer, target_rate: int = TARGET_SAMPLE_RATE) -> AudioBuffer:
    if buffer.sample_rate == target_rate:
        return buffer

    original = buffer.samples
    if len(original) <= 1:
        return AudioBuffer(samples=original.astype(np.float32, copy=True), sample_rate=target_rate)

    new_length = max(1, int(round(len(original) * target_rate / buffer.sample_rate)))
    source_positions = np.linspace(0.0, 1.0, num=len(original), endpoint=True)
    target_positions = np.linspace(0.0, 1.0, num=new_length, endpoint=True)
    resampled = np.interp(target_positions, source_positions, original).astype(np.float32)
    return AudioBuffer(samples=resampled, sample_rate=target_rate)


def _pcm_to_float(raw_frames: bytes, sample_width: int) -> np.ndarray:
    if sample_width == 1:
        data = np.frombuffer(raw_frames, dtype=np.uint8).astype(np.float32)
        return (data - 128.0) / 128.0

    if sample_width == 2:
        data = np.frombuffer(raw_frames, dtype="<i2").astype(np.float32)
        return data / 32768.0

    if sample_width == 3:
        data = np.frombuffer(raw_frames, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = data[:, 0] | (data[:, 1] << 8) | (data[:, 2] << 16)
        values = np.where(values & 0x800000, values - 0x1000000, values)
        return values.astype(np.float32) / 8388608.0

    if sample_width == 4:
        data = np.frombuffer(raw_frames, dtype="<i4").astype(np.float32)
        return data / 2147483648.0

    raise AudioDecodeError(f"Unsupported WAV sample width: {sample_width} bytes.")
