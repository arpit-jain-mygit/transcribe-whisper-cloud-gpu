#!/usr/bin/env python3
"""
Stage 3 — Rule-based post-processing with detailed logs

Outputs:
- outputs/refined_transcript.json
- outputs/raw_vs_refined.diff.txt
"""

import json
import difflib
import logging
import time
from collections import Counter

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------
INPUT_FILE = "outputs/raw_transcript.json"
OUTPUT_REFINED = "outputs/refined_transcript.json"
OUTPUT_DIFF = "outputs/raw_vs_refined.diff.txt"

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)

# ------------------------------------------------------------
# RULES (extend safely here)
# ------------------------------------------------------------
REPLACEMENTS = {
    "कारिक्रियम": "कार्यक्रम",
    "दर्पन": "दर्पण",
    "कशायक": "कषायक",
    "जैप": "जय",
    "बीगमगंच": "बीगमगंज",
    "सहारनपूर": "सहारनपुर",
}

# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------
def apply_rules(text: str, stats: Counter) -> str:
    original = text
    for wrong, right in REPLACEMENTS.items():
        if wrong in text:
            count = text.count(wrong)
            stats[wrong] += count
            text = text.replace(wrong, right)
    return text


# ------------------------------------------------------------
# START
# ------------------------------------------------------------
start_time = time.time()

logger.info("=" * 80)
logger.info("🧹 RULE-BASED POST-PROCESSING STARTED")
logger.info(f"📄 Input  : {INPUT_FILE}")
logger.info(f"📄 Output : {OUTPUT_REFINED}")
logger.info("=" * 80)

# ------------------------------------------------------------
# LOAD RAW TRANSCRIPT
# ------------------------------------------------------------
logger.info("📂 Loading raw transcript...")

with open(INPUT_FILE, encoding="utf-8") as f:
    raw = json.load(f)

segments = raw["segments"]
raw_lines = [s["text"] for s in segments]

logger.info(f"🧩 Segments loaded: {len(raw_lines)}")
logger.info(f"📊 Avg confidence : {raw.get('avg_confidence')}")

# ------------------------------------------------------------
# APPLY RULES
# ------------------------------------------------------------
logger.info("🔧 Applying normalization rules...")

rule_stats = Counter()
refined_lines = []

for i, line in enumerate(raw_lines, start=1):
    refined = apply_rules(line, rule_stats)
    refined_lines.append(refined)

    if refined != line:
        logger.debug(f"✏️ Line {i} changed")

refined_text = " ".join(refined_lines)

logger.info("✅ Rule application complete")

if rule_stats:
    logger.info("📈 Rule hit counts:")
    for rule, count in rule_stats.items():
        logger.info(f"   '{rule}' → {count} replacements")
else:
    logger.info("ℹ️ No rule replacements applied")

# ------------------------------------------------------------
# DIFF GENERATION
# ------------------------------------------------------------
logger.info("📐 Generating raw vs refined diff...")

diff = list(
    difflib.unified_diff(
        raw_lines,
        refined_lines,
        fromfile="raw",
        tofile="refined",
        lineterm=""
    )
)

with open(OUTPUT_DIFF, "w", encoding="utf-8") as f:
    f.write("\n".join(diff))

logger.info(
    f"📄 Diff saved → {OUTPUT_DIFF} "
    f"({len(diff)} diff lines)"
)

# ------------------------------------------------------------
# SAVE REFINED OUTPUT
# ------------------------------------------------------------
logger.info("💾 Saving refined transcript...")

refined_out = {
    "avg_confidence": raw["avg_confidence"],
    "text": refined_text,
    "segments": segments,
}

with open(OUTPUT_REFINED, "w", encoding="utf-8") as f:
    json.dump(refined_out, f, ensure_ascii=False, indent=2)

# ------------------------------------------------------------
# DONE
# ------------------------------------------------------------
elapsed = time.time() - start_time

logger.info("=" * 80)
logger.info("✅ POST-PROCESSING COMPLETE")
logger.info(f"⏱️ Time taken : {elapsed:.2f}s")
logger.info(f"📄 Refined    : {OUTPUT_REFINED}")
logger.info(f"📄 Diff       : {OUTPUT_DIFF}")
logger.info("=" * 80)
