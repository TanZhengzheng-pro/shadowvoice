# Pronunciation Feedback MVP Spec

## Scope
This document is the single source of truth for the first ShadowVoice pronunciation backend milestone.

Inputs:
- `target_text`: required string
- `user_audio`: required WAV audio
- `ref_audio`: optional WAV audio

Outputs:
- `overall_score`: float in `[0, 100]`
- `worst_segments`: up to 3 lowest-scoring time spans from the user audio
- `notes`: human-readable explanation strings

## Input Contract
- The API accepts JSON.
- Audio is passed as base64-encoded WAV bytes.
- `user_audio_b64` is required.
- `ref_audio_b64` is optional.

## Audio Pipeline
1. Decode WAV bytes.
2. Convert to mono.
3. Peak-normalize amplitude.
4. Resample to 16 kHz.
5. Extract log-mel features with:
   - FFT size: 512
   - Window length: 25 ms
   - Hop length: 10 ms
   - Mel bins: 40

## Scoring Logic
Primary mode:
- If `ref_audio` is provided, compare user and reference log-mel features with DTW.

Fallback mode:
- If `ref_audio` is missing, build a smoothed self-reference proxy from the user's own log-mel sequence.
- This mode measures consistency and stability more than absolute pronunciation correctness.

DTW details:
- Local similarity is cosine similarity between per-frame log-mel vectors.
- Similarity is mapped to `[0, 100]`.
- DTW finds the minimum-cost alignment over frame sequences.
- `overall_score` is the mean aligned similarity, with a small duration-ratio penalty in reference mode to avoid over-rewarding length mismatches.

## Worst Segments
- Collapse DTW alignment scores back onto user frames.
- Partition the user timeline into contiguous windows.
- Window size adapts to utterance duration, clamped to `[0.3, 1.0]` seconds.
- Return the 3 windows with the lowest mean score.

Each segment includes:
- `start_sec`
- `end_sec`
- `segment_score`

## Notes
The response includes short notes that explain:
- whether reference or fallback mode was used
- what low segment scores mean
- that `target_text` is accepted now and reserved for later text-aware upgrades such as alignment or GOP

## Non-Goals for This Milestone
- Forced alignment
- GOP scoring
- Word-level or phoneme-level labels
- ASR-based correctness checks
- Multi-format audio ingestion beyond WAV
