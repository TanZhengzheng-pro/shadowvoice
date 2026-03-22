from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from app.audio import AudioBuffer, TARGET_SAMPLE_RATE, ensure_sample_rate, load_wav_mono

EPSILON = 1e-8
FFT_SIZE = 512
WINDOW_LENGTH = 400
HOP_LENGTH = 160
MEL_BINS = 40


@dataclass(frozen=True)
class SegmentScore:
    start_sec: float
    end_sec: float
    segment_score: float


@dataclass(frozen=True)
class PronunciationResult:
    overall_score: float
    worst_segments: list[SegmentScore]
    notes: list[str]


def analyze_pronunciation(
    target_text: str,
    user_audio_bytes: bytes,
    ref_audio_bytes: bytes | None = None,
) -> PronunciationResult:
    if not target_text or not target_text.strip():
        raise ValueError("target_text must not be empty.")

    user_audio = ensure_sample_rate(load_wav_mono(user_audio_bytes), TARGET_SAMPLE_RATE)
    user_features = extract_log_mel_features(user_audio.samples, user_audio.sample_rate)

    notes = []

    if ref_audio_bytes is not None:
        ref_audio = ensure_sample_rate(load_wav_mono(ref_audio_bytes), TARGET_SAMPLE_RATE)
        ref_features = extract_log_mel_features(ref_audio.samples, ref_audio.sample_rate)
        duration_ratio = _duration_ratio(user_audio, ref_audio)
        notes.append(
            "Reference audio provided; score is DTW-aligned log-mel similarity against that reference."
        )
    else:
        ref_audio = None
        ref_features = _build_proxy_reference(user_features)
        duration_ratio = 1.0
        notes.append(
            "No reference audio provided; using a smoothed self-reference proxy, so the score reflects consistency more than absolute correctness."
        )

    score_matrix = _frame_score_matrix(user_features, ref_features)
    cost_matrix = 1.0 - (score_matrix / 100.0)
    alignment_path = _dtw_path(cost_matrix)

    alignment_scores = np.array(
        [score_matrix[user_index, ref_index] for user_index, ref_index in alignment_path],
        dtype=np.float32,
    )
    user_frame_scores = _collapse_to_user_frames(len(user_features), alignment_path, score_matrix)

    overall_score = float(np.mean(alignment_scores))
    if ref_audio is not None:
        overall_score *= 0.85 + (0.15 * duration_ratio)
    else:
        overall_score *= 0.92

    overall_score = _clamp_score(overall_score)

    notes.append(
        "Lower segment scores indicate spans where the acoustic pattern diverged more strongly."
    )
    notes.append(
        "target_text is accepted now and reserved for later text-aware alignment upgrades."
    )

    if _is_low_energy(user_audio.samples):
        notes.append("The uploaded audio is very quiet; scores may be less stable.")

    worst_segments = _extract_worst_segments(
        frame_scores=user_frame_scores,
        duration_sec=user_audio.duration_sec,
        sample_rate=user_audio.sample_rate,
        target_text=target_text,
    )

    return PronunciationResult(
        overall_score=round(overall_score, 2),
        worst_segments=worst_segments,
        notes=notes,
    )


def extract_log_mel_features(samples: np.ndarray, sample_rate: int) -> np.ndarray:
    audio = np.asarray(samples, dtype=np.float32)
    if audio.size == 0:
        raise ValueError("Audio sample buffer is empty.")

    if audio.size < WINDOW_LENGTH:
        audio = np.pad(audio, (0, WINDOW_LENGTH - audio.size))

    remainder = (audio.size - WINDOW_LENGTH) % HOP_LENGTH
    if remainder:
        audio = np.pad(audio, (0, HOP_LENGTH - remainder))

    frame_starts = range(0, audio.size - WINDOW_LENGTH + 1, HOP_LENGTH)
    frames = np.stack([audio[start : start + WINDOW_LENGTH] for start in frame_starts])
    window = np.hanning(WINDOW_LENGTH).astype(np.float32)
    spectrum = np.fft.rfft(frames * window, n=FFT_SIZE, axis=1)
    power = np.abs(spectrum).astype(np.float32) ** 2

    mel_filters = _build_mel_filter_bank(sample_rate, FFT_SIZE, MEL_BINS)
    mel_power = power @ mel_filters.T
    log_mel = np.log(mel_power + 1e-6).astype(np.float32)
    log_mel -= log_mel.mean(axis=0, keepdims=True)
    return log_mel


def _build_mel_filter_bank(sample_rate: int, n_fft: int, mel_bins: int) -> np.ndarray:
    mel_low = _hz_to_mel(0.0)
    mel_high = _hz_to_mel(sample_rate / 2.0)
    mel_points = np.linspace(mel_low, mel_high, mel_bins + 2)
    hz_points = _mel_to_hz(mel_points)
    bin_points = np.floor((n_fft + 1) * hz_points / sample_rate).astype(int)
    max_bin = n_fft // 2

    filters = np.zeros((mel_bins, max_bin + 1), dtype=np.float32)

    for index in range(mel_bins):
        left = min(bin_points[index], max_bin)
        center = min(max(left + 1, bin_points[index + 1]), max_bin)
        right = min(max(center + 1, bin_points[index + 2]), max_bin)

        if center == right:
            continue

        for bin_index in range(left, center):
            filters[index, bin_index] = (bin_index - left) / max(center - left, 1)
        for bin_index in range(center, right):
            filters[index, bin_index] = (right - bin_index) / max(right - center, 1)

    return filters


def _frame_score_matrix(user_features: np.ndarray, ref_features: np.ndarray) -> np.ndarray:
    user_norm = user_features / np.maximum(
        np.linalg.norm(user_features, axis=1, keepdims=True), EPSILON
    )
    ref_norm = ref_features / np.maximum(
        np.linalg.norm(ref_features, axis=1, keepdims=True), EPSILON
    )
    cosine = np.clip(user_norm @ ref_norm.T, -1.0, 1.0)
    return ((cosine + 1.0) * 50.0).astype(np.float32)


def _dtw_path(cost_matrix: np.ndarray) -> list[tuple[int, int]]:
    user_frames, ref_frames = cost_matrix.shape
    dtw = np.full((user_frames + 1, ref_frames + 1), np.inf, dtype=np.float64)
    trace = np.zeros((user_frames, ref_frames), dtype=np.uint8)
    dtw[0, 0] = 0.0

    for user_index in range(1, user_frames + 1):
        for ref_index in range(1, ref_frames + 1):
            previous = (
                dtw[user_index - 1, ref_index - 1],
                dtw[user_index - 1, ref_index],
                dtw[user_index, ref_index - 1],
            )
            move = int(np.argmin(previous))
            dtw[user_index, ref_index] = cost_matrix[user_index - 1, ref_index - 1] + previous[move]
            trace[user_index - 1, ref_index - 1] = move

    user_index = user_frames
    ref_index = ref_frames
    path: list[tuple[int, int]] = []

    while user_index > 0 and ref_index > 0:
        path.append((user_index - 1, ref_index - 1))
        move = trace[user_index - 1, ref_index - 1]
        if move == 0:
            user_index -= 1
            ref_index -= 1
        elif move == 1:
            user_index -= 1
        else:
            ref_index -= 1

    while user_index > 0:
        user_index -= 1
        path.append((user_index, 0))
    while ref_index > 0:
        ref_index -= 1
        path.append((0, ref_index))

    path.reverse()
    return path


def _collapse_to_user_frames(
    user_frame_count: int,
    alignment_path: list[tuple[int, int]],
    score_matrix: np.ndarray,
) -> np.ndarray:
    frame_totals = np.zeros(user_frame_count, dtype=np.float32)
    frame_counts = np.zeros(user_frame_count, dtype=np.float32)

    for user_index, ref_index in alignment_path:
        frame_totals[user_index] += score_matrix[user_index, ref_index]
        frame_counts[user_index] += 1.0

    return frame_totals / np.maximum(frame_counts, 1.0)


def _extract_worst_segments(
    frame_scores: np.ndarray,
    duration_sec: float,
    sample_rate: int,
    target_text: str,
) -> list[SegmentScore]:
    if frame_scores.size == 0:
        return []

    token_count = max(1, len([token for token in target_text.split() if token]))
    segment_count_hint = max(3, min(8, token_count * 2))
    window_sec = min(1.0, max(0.3, duration_sec / segment_count_hint if duration_sec else 0.3))
    frame_hop_sec = HOP_LENGTH / sample_rate
    window_frames = max(1, int(round(window_sec / frame_hop_sec)))

    segments: list[SegmentScore] = []
    for start_frame in range(0, len(frame_scores), window_frames):
        end_frame = min(len(frame_scores), start_frame + window_frames)
        if end_frame <= start_frame:
            continue
        segment_score = _clamp_score(float(np.mean(frame_scores[start_frame:end_frame])))
        start_sec = start_frame * frame_hop_sec
        end_sec = min(duration_sec, ((end_frame - 1) * frame_hop_sec) + (WINDOW_LENGTH / sample_rate))
        segments.append(
            SegmentScore(
                start_sec=round(start_sec, 3),
                end_sec=round(max(end_sec, start_sec + frame_hop_sec), 3),
                segment_score=round(segment_score, 2),
            )
        )

    segments.sort(key=lambda segment: segment.segment_score)
    return segments[:3]


def _build_proxy_reference(user_features: np.ndarray) -> np.ndarray:
    if len(user_features) < 3:
        return np.copy(user_features)

    kernel_size = min(11, len(user_features))
    if kernel_size % 2 == 0:
        kernel_size -= 1
    kernel_size = max(kernel_size, 3)

    padding = kernel_size // 2
    padded = np.pad(user_features, ((padding, padding), (0, 0)), mode="edge")
    smoothed = np.empty_like(user_features)

    for frame_index in range(len(user_features)):
        smoothed[frame_index] = padded[frame_index : frame_index + kernel_size].mean(axis=0)

    return smoothed


def _duration_ratio(left: AudioBuffer, right: AudioBuffer) -> float:
    longest = max(left.duration_sec, right.duration_sec, EPSILON)
    shortest = min(left.duration_sec, right.duration_sec)
    return shortest / longest


def _is_low_energy(samples: np.ndarray) -> bool:
    return float(np.sqrt(np.mean(np.square(samples)))) < 0.02


def _clamp_score(score: float) -> float:
    return max(0.0, min(100.0, score))


def _hz_to_mel(hz: float) -> float:
    return 2595.0 * np.log10(1.0 + (hz / 700.0))


def _mel_to_hz(mel: np.ndarray) -> np.ndarray:
    return 700.0 * (10.0 ** (mel / 2595.0) - 1.0)
