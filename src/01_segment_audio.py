#!/usr/bin/env python3
"""
Stage 1 — Silence-aware audio segmentation

Outputs:
- clips/*.wav
- pipeline_state.json
"""

from pydub import AudioSegment, silence
from pathlib import Path
import json
import logging

# ------------------------------------------------------------
# PATH RESOLUTION (ROBUST)
# ------------------------------------------------------------
# src/01_segment_audio.py → project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT = PROJECT_ROOT / "audio" / "215.wav"
OUT_DIR = PROJECT_ROOT / "clips"
STATE = PROJECT_ROOT / "pipeline_state.json"

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------
MAX_MS = 30_000
MIN_CLIP_MS = 12_000
MIN_SILENCE = 600
THRESH = -40
KEEP_SILENCE_MS = 300

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)

# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------
if not INPUT.exists():
    raise FileNotFoundError(f"Input audio not found: {INPUT}")

OUT_DIR.mkdir(parents=True, exist_ok=True)

logger.info(f"🎧 Using input audio → {INPUT}")
logger.info(f"📁 Clips output dir → {OUT_DIR}")
logger.info(f"📄 State file → {STATE}")

# ------------------------------------------------------------
# LOAD AUDIO
# ------------------------------------------------------------
logger.info("🎧 Loading input audio")
audio = AudioSegment.from_wav(INPUT)
total_ms = len(audio)

logger.info(
    f"🎧 Audio duration: {total_ms/1000:.1f}s "
    f"({total_ms/60000:.1f} min)"
)

clips = []
cursor = 0
clip_idx = 0

logger.info("✂️ Starting silence-aware segmentation")

# ------------------------------------------------------------
# SEGMENT LOOP
# ------------------------------------------------------------
while cursor < total_ms:
    window = audio[cursor: cursor + MAX_MS]

    sils = silence.detect_silence(
        window,
        min_silence_len=MIN_SILENCE,
        silence_thresh=THRESH
    )

    cut = None
    if sils:
        last_silence_start = sils[-1][0]
        if last_silence_start >= MIN_CLIP_MS:
            cut = last_silence_start

    if cut:
        clip = audio[cursor: cursor + cut + KEEP_SILENCE_MS]
        advance = cut
    else:
        clip = window
        advance = len(window)

    fname = OUT_DIR / f"clip_{clip_idx:03d}.wav"
    clip.export(fname, format="wav")

    clips.append({
        "file": str(fname.relative_to(PROJECT_ROOT)),
        "start_ms": cursor,
        "duration_ms": len(clip)
    })

    logger.info(
        f"✂️ Clip {clip_idx+1:03d} | "
        f"start={cursor/1000:.1f}s | "
        f"dur={len(clip)/1000:.1f}s"
    )

    cursor += advance
    clip_idx += 1

# ------------------------------------------------------------
# WRITE PIPELINE STATE
# ------------------------------------------------------------
state = {
    "input_audio": str(INPUT.relative_to(PROJECT_ROOT)),
    "total_duration_ms": total_ms,
    "total_clips": len(clips),
    "clips": clips,
    "clips_processed": []
}

STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")

logger.info("=" * 80)
logger.info(f"✅ Segmentation complete — {len(clips)} clips created")
logger.info(f"📄 State written → {STATE}")
logger.info("=" * 80)
