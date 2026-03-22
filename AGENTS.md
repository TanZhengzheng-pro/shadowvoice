# Project Instructions for Codex

## Goal (MVP)
Build a minimal pronunciation feedback backend.
Input: user audio + target text (+ optional reference audio)
Output: JSON feedback with overall score + top-3 worst segments (time ranges) + explanations.

## Tech Constraints
- Language: Python 3.11+
- Web API: FastAPI
- Keep dependencies minimal.
- First milestone uses DTW + log-mel similarity (no forced alignment/GOP yet), but design interfaces for later upgrade.

## Repo Structure
- backend/: FastAPI service
- docs/pronunciation-spec.md: single source of truth for scoring/feedback logic

## Must Deliver
- `backend/` runnable with one command
- `/analyze` endpoint
- Example request/response in README
- Basic unit test for scoring function
