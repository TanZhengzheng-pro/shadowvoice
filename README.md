# ShadowVoice Pronunciation MVP

## What
Pronunciation feedback MVP built with FastAPI.

The current backend compares WAV audio with DTW + log-mel similarity and returns:
- `overall_score`
- `worst_segments` (top 3 spans with `start_sec`, `end_sec`, `segment_score`)
- `notes`

## Docs
- `docs/pronunciation-spec.md`
- `backend/README.md`

## Run
1. `cd backend`
2. `python3 -m venv .venv`
3. `source .venv/bin/activate`
4. `pip install -e ".[dev]"`
5. `python -m app.main`

## API
`POST /analyze`

Request body:

```json
{
  "target_text": "shadow voice",
  "user_audio_b64": "UklGRi4uLg==",
  "ref_audio_b64": "UklGRi4uLg=="
}
```

- `user_audio_b64` is required and must be a base64-encoded WAV payload.
- `ref_audio_b64` is optional. When omitted, the MVP falls back to a smoothed self-reference proxy and the score becomes a consistency signal rather than a strict correctness score.

Example response:

```json
{
  "overall_score": 84.6,
  "worst_segments": [
    {
      "start_sec": 0.5,
      "end_sec": 0.95,
      "segment_score": 63.2
    },
    {
      "start_sec": 1.4,
      "end_sec": 1.85,
      "segment_score": 68.9
    },
    {
      "start_sec": 0.0,
      "end_sec": 0.45,
      "segment_score": 71.4
    }
  ],
  "notes": [
    "Reference audio provided; score is DTW-aligned log-mel similarity against that reference.",
    "Lower segment scores indicate spans where the acoustic pattern diverged more strongly.",
    "target_text is accepted now and reserved for later text-aware alignment upgrades."
  ]
}
```
