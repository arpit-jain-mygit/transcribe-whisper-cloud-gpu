#!/usr/bin/env python3
"""
SMART SILENCE-AWARE FAST-WHISPER PIPELINE (GPU, large-v3)

Features:
- Silence-aware segmentation
- 30s max clips
- Resumable with state + cache
- GPU accelerated (faster-whisper, FP16)
- Pure Whisper output (NO LLM post-processing)
- Output bundling
- Graceful auto-pod shutdown AFTER download window
"""

import os
import json
import time
import pickle
import tarfile
import logging
from datetime import datetime

from pydub import AudioSegment, silence
from faster_whisper import WhisperModel


# ================= CONFIG =================
INPUT_FILE = "../audio/215.wav"
OUTPUT_DIR = "../clips"
STATE_FILE = "../pipeline_state.json"

# Smart segmentation
MAX_CLIP_MS = 30_000
MIN_CLIP_MS = 12_000
SILENCE_THRESH = -40
MIN_SILENCE_MS = 600
KEEP_SILENCE_MS = 300

# Shutdown behavior
AUTO_SHUTDOWN = True
SHUTDOWN_DELAY_SEC = 300   # 5 minutes to download bundle


# ================= LOGGING =================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler("pipeline.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

logger.info("=" * 90)
logger.info("🚀 SMART SILENCE-AWARE FAST-WHISPER PIPELINE (GPU, NO LLM)")
logger.info("=" * 90)


# ================= HELPERS =================
def format_time(sec: float) -> str:
    return time.strftime("%H:%M:%S", time.gmtime(sec))


def format_ms(ms: int) -> str:
    return f"{ms / 1000:.1f}s"


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            logger.info("📂 Loaded pipeline state")
            return json.load(f)
    logger.info("🆕 No state found, starting fresh")
    return {"clips_processed": []}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    logger.info(
        f"💾 State saved → "
        f"{len(state['clips_processed'])}/{state.get('total_clips', '?')} clips done"
    )


def smart_split(audio: AudioSegment):
    logger.info("✂️ Performing silence-aware segmentation")
    clips = []
    cursor = 0

    while cursor < len(audio):
        window = audio[cursor: cursor + MAX_CLIP_MS]

        silences = silence.detect_silence(
            window,
            min_silence_len=MIN_SILENCE_MS,
            silence_thresh=SILENCE_THRESH
        )

        cut = None
        if silences:
            last_silence_start = silences[-1][0]
            if last_silence_start >= MIN_CLIP_MS:
                cut = last_silence_start

        if cut:
            clip = audio[cursor: cursor + cut + KEEP_SILENCE_MS]
            cursor += cut
        else:
            clip = audio[cursor: cursor + MAX_CLIP_MS]
            cursor += MAX_CLIP_MS

        clips.append(clip)

    logger.info(f"✅ Segmented into {len(clips)} logical clips")
    return clips


def bundle_outputs(bundle_name="outputs_bundle.tar.gz"):
    logger.info("📦 Bundling outputs for download")

    with tarfile.open(bundle_name, "w:gz") as tar:
        if os.path.exists("pipeline.log"):
            tar.add("pipeline.log")
        for f in os.listdir(".."):
            if f.startswith("hindi_pipeline_") and f.endswith(".txt"):
                tar.add(f)

    logger.info(f"📦 Bundle created → {bundle_name}")
    return bundle_name


def shutdown_pod_with_delay(delay_sec):
    logger.warning(
        f"🛑 AUTO-SHUTDOWN IN {delay_sec} SECONDS — DOWNLOAD OUTPUTS NOW"
    )
    time.sleep(delay_sec)
    os.system("shutdown -h now")


# ================= LOAD MODEL =================
t0 = time.time()
logger.info("🧠 Loading faster-whisper large-v3 on GPU (FP16)")
model = WhisperModel(
    "large-v3",
    device="cuda",
    compute_type="float16"
)
logger.info(f"🧠 Model ready in {time.time() - t0:.1f}s")


# ================= LOAD STATE =================
state = load_state()


# ================= CREATE CLIPS =================
if "clips" not in state:
    audio = AudioSegment.from_wav(INPUT_FILE)
    total_audio_ms = len(audio)
    state["total_duration"] = total_audio_ms / 1000

    logger.info(
        f"🎧 Audio duration: {format_time(state['total_duration'])} "
        f"({state['total_duration'] / 60:.1f} min)"
    )

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    audio_clips = smart_split(audio)

    clips = []
    cursor_ms = 0

    for idx, clip in enumerate(audio_clips):
        clip_len = len(clip)
        clip_file = f"{OUTPUT_DIR}/clip_{idx:03d}.wav"
        clip.export(clip_file, format="wav")

        logger.info(
            f"✂️ Clip {idx + 1:03d} | "
            f"start={format_time(cursor_ms / 1000)} | "
            f"duration={format_ms(clip_len)}"
        )

        clips.append({
            "file": clip_file,
            "start_ms": cursor_ms,
            "duration_ms": clip_len
        })

        cursor_ms += clip_len

    state["clips"] = clips
    state["total_clips"] = len(clips)
    save_state(state)

else:
    clips = state["clips"]
    logger.info(f"📁 Using existing clips → {len(clips)} clips")


# ================= PROCESS CLIPS =================
logger.info("🎙️ Starting transcription (resumable)")
all_segments = []

for i, clip in enumerate(clips):
    clip_file = clip["file"]
    start_offset_sec = clip["start_ms"] / 1000
    cache_file = f"{clip_file}.cache.pkl"

    logger.info(
        f"▶ Clip {i + 1}/{len(clips)} | "
        f"{os.path.basename(clip_file)} | "
        f"start={format_time(start_offset_sec)} | "
        f"dur={format_ms(clip['duration_ms'])}"
    )

    if i in state["clips_processed"]:
        with open(cache_file, "rb") as f:
            segments = pickle.load(f)
        logger.info("   ⚡ Loaded cached transcription")
    else:
        try:
            t0 = time.time()
            logger.info("   🧠 GPU inference started")

            segments, _ = model.transcribe(
                clip_file,
                language="hi",
                beam_size=5,
                vad_filter=False
            )

            segments = list(segments)

            logger.info(
                f"   ✅ Transcribed in {time.time() - t0:.1f}s "
                f"({len(segments)} segments)"
            )

            with open(cache_file, "wb") as f:
                pickle.dump(segments, f)

            state["clips_processed"].append(i)
            save_state(state)

        except KeyboardInterrupt:
            logger.warning("⏸️ Interrupted — state saved, resume safe")
            exit(1)
        except Exception as e:
            logger.error(f"❌ Clip failed: {e}")
            continue

    for seg in segments:
        all_segments.append({
            "start": seg.start + start_offset_sec,
            "end": seg.end + start_offset_sec,
            "text": seg.text.strip()
        })

logger.info(f"🧩 Collected {len(all_segments)} total segments")


# ================= FINAL MERGE =================
if len(state["clips_processed"]) == state["total_clips"]:
    logger.info("🧵 All clips complete — merging transcript")

    all_segments.sort(key=lambda x: x["start"])
    final_text = " ".join(s["text"] for s in all_segments)

    out_file = f"hindi_pipeline_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(final_text)

    state["complete"] = True
    save_state(state)

    logger.info("=" * 90)
    logger.info("🇮🇳 PIPELINE COMPLETE SUCCESSFULLY")
    logger.info(f"📄 Output → {out_file}")
    logger.info("📊 Logs   → pipeline.log")
    logger.info("=" * 90)

    bundle = bundle_outputs()

    logger.info("⬇️ DOWNLOAD THIS FILE BEFORE SHUTDOWN")
    logger.info(f"📦 {bundle}")
    logger.info(
        "Run from LOCAL machine:\n"
        "scp -i ~/.ssh/id_ed25519 -P 40017 "
        "root@213.192.2.119:/workspace/outputs_bundle.tar.gz ."
    )

    if AUTO_SHUTDOWN:
        shutdown_pod_with_delay(SHUTDOWN_DELAY_SEC)

else:
    pending = state["total_clips"] - len(state["clips_processed"])
    logger.warning(f"⏳ {pending} clips remaining — resume anytime")
