#!/usr/bin/env python3
"""
Stage 2 — Transcribe audio clips with faster-whisper (GPU)

Outputs:
- outputs/raw_transcript.json
"""

import os
import json
import math
import pickle
import time
import logging
from pathlib import Path
from faster_whisper import WhisperModel

# ------------------------------------------------------------
# PATH RESOLUTION (ROBUST)
# src/02_transcribe_clips.py → project root
# ------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent

OUTPUT_DIR = PROJECT_ROOT / "outputs"
STATE_FILE = PROJECT_ROOT / "pipeline_state.json"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


def fmt(sec: float) -> str:
    return f"{sec:.1f}s"


def compute_confidence(avg_logprob, no_speech_prob):
    """
    Deterministic confidence score ∈ [0,1]
    """
    try:
        return max(
            0.0,
            min(1.0, math.exp(avg_logprob) * (1.0 - no_speech_prob))
        )
    except Exception:
        return 0.0


# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------
if not STATE_FILE.exists():
    raise FileNotFoundError(f"pipeline_state.json not found: {STATE_FILE}")

logger.info(f"📄 State file  → {STATE_FILE}")
logger.info(f"📁 Output dir → {OUTPUT_DIR}")

# ------------------------------------------------------------
# LOAD MODEL
# ------------------------------------------------------------
logger.info("=" * 80)
logger.info("🧠 Loading faster-whisper large-v3 (GPU, FP16)")
t0 = time.time()

model = WhisperModel(
    "large-v3",
    device="cuda",
    compute_type="float16"
)

logger.info(f"🧠 Model loaded in {fmt(time.time() - t0)}")
logger.info("=" * 80)

# ------------------------------------------------------------
# LOAD STATE
# ------------------------------------------------------------
with STATE_FILE.open() as f:
    state = json.load(f)

clips = state["clips"]
processed = set(state.get("clips_processed", []))

logger.info(f"📁 Total clips      : {len(clips)}")
logger.info(f"⚡ Already processed: {len(processed)}")

all_segments = []

# ------------------------------------------------------------
# TRANSCRIPTION LOOP
# ------------------------------------------------------------
logger.info("🎙️ Starting transcription loop")
overall_start = time.time()

for idx, clip in enumerate(clips):
    if idx in processed:
        logger.info(f"⏭️  Skipping clip {idx+1}/{len(clips)} (cached)")
        continue

    clip_path = PROJECT_ROOT / clip["file"]
    start_offset = clip["start_ms"] / 1000
    cache_file = clip_path.with_suffix(clip_path.suffix + ".cache.pkl")

    logger.info("-" * 80)
    logger.info(
        f"▶ Clip {idx+1}/{len(clips)} | "
        f"{clip_path.name} | "
        f"start={start_offset:.1f}s | "
        f"dur={clip['duration_ms']/1000:.1f}s"
    )

    t_clip = time.time()
    logger.info("   🧠 GPU inference started")

    segments, info = model.transcribe(
        str(clip_path),
        language="hi",
        beam_size=5
    )

    segments = list(segments)

    logger.info(
        f"   ✅ Inference done in {fmt(time.time() - t_clip)} | "
        f"segments={len(segments)} | "
        f"language={info.language}"
    )

    # Cache raw segments
    with cache_file.open("wb") as f:
        pickle.dump(segments, f)
    logger.info("   💾 Cached raw segments")

    for seg in segments:
        conf = compute_confidence(
            seg.avg_logprob,
            seg.no_speech_prob
        )

        all_segments.append({
            "start": round(seg.start + start_offset, 3),
            "end": round(seg.end + start_offset, 3),
            "text": seg.text.strip(),
            "confidence": round(conf, 4)
        })

    processed.add(idx)
    state["clips_processed"] = sorted(processed)

    with STATE_FILE.open("w") as f:
        json.dump(state, f, indent=2)

    logger.info(
        f"   📊 Progress: {len(processed)}/{len(clips)} clips done"
    )

# ------------------------------------------------------------
# FINAL OUTPUT
# ------------------------------------------------------------
logger.info("=" * 80)
logger.info("🧩 Transcription loop complete")
logger.info(f"⏱️ Total time: {fmt(time.time() - overall_start)}")

avg_conf = round(
    sum(s["confidence"] for s in all_segments) / max(len(all_segments), 1),
    4
)

raw_output = {
    "avg_confidence": avg_conf,
    "segments": all_segments
}

out_path = OUTPUT_DIR / "raw_transcript.json"
with out_path.open("w", encoding="utf-8") as f:
    json.dump(raw_output, f, ensure_ascii=False, indent=2)

logger.info(f"📄 Saved: {out_path}")
logger.info(f"📊 Avg confidence: {avg_conf}")
logger.info("=" * 80)
