from __future__ import annotations

from dataclasses import asdict

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.audio import AudioDecodeError, decode_base64_audio
from app.scoring import PronunciationResult, SegmentScore, analyze_pronunciation

app = FastAPI(title="ShadowVoice Pronunciation MVP", version="0.1.0")


class AnalyzeRequest(BaseModel):
    target_text: str = Field(..., min_length=1)
    user_audio_b64: str = Field(..., min_length=1)
    ref_audio_b64: str | None = None


class SegmentResponse(BaseModel):
    start_sec: float
    end_sec: float
    segment_score: float

    @classmethod
    def from_segment(cls, segment: SegmentScore) -> "SegmentResponse":
        return cls(**asdict(segment))


class AnalyzeResponse(BaseModel):
    overall_score: float
    worst_segments: list[SegmentResponse]
    notes: list[str]

    @classmethod
    def from_result(cls, result: PronunciationResult) -> "AnalyzeResponse":
        return cls(
            overall_score=result.overall_score,
            worst_segments=[SegmentResponse.from_segment(segment) for segment in result.worst_segments],
            notes=result.notes,
        )


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest) -> AnalyzeResponse:
    try:
        user_audio_bytes = decode_base64_audio(request.user_audio_b64)
        ref_audio_bytes = (
            decode_base64_audio(request.ref_audio_b64) if request.ref_audio_b64 is not None else None
        )
        result = analyze_pronunciation(
            target_text=request.target_text,
            user_audio_bytes=user_audio_bytes,
            ref_audio_bytes=ref_audio_bytes,
        )
    except AudioDecodeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return AnalyzeResponse.from_result(result)


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)
