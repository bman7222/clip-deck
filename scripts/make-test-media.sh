#!/usr/bin/env bash
# Generate the test MKV fixtures with Homebrew ffmpeg (a build-time tool only; never shipped, no media in git).
# Usage: ./scripts/make-test-media.sh [output-dir]        default: build/fixtures
# Needs: ffmpeg with libx264 and libx265 (brew install ffmpeg).
#
# Every video is a solid colour that changes each second (second s shows colour s mod 8 as RGB bits:
# 0 black, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white). Every audio track is a 880 Hz beep
# of 0.2 s at the start of each even second (0 s, 2 s, 4 s, ...), so sync can be measured. All are 8 s long.
#
# Fixtures (names are used by the tests):
#   01-h264-bframes-aac-srt-ass.mkv  H.264 with B-frames, AAC stereo, SRT + ASS tracks (Japanese)
#   02-hevc-main10-flac.mkv          HEVC Main10, open GOP, FLAC audio
#   03-offset-ac3-51-srt.mkv         video starts at 1.0 s, audio at 1.5 s, AC-3 5.1, SRT track
#   04-nosubs-aac51.mkv              H.264, AAC 5.1, no subtitle tracks
#   05-h264-hi10p.mkv                H.264 High 10 (must be rejected by the importer)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build/fixtures}"
SELF="$ROOT/scripts/make-test-media.sh"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found: brew install ffmpeg" >&2
  exit 1
fi

NAMES=(
  01-h264-bframes-aac-srt-ass.mkv
  02-hevc-main10-flac.mkv
  03-offset-ac3-51-srt.mkv
  04-nosubs-aac51.mkv
  05-h264-hi10p.mkv
)

# The dictionary UI tests (-uiTestingDictionary) read these zips from $CLIPDECK_FIXTURES/dictionaries.
mkdir -p "$OUT/dictionaries"
cp "$ROOT"/scripts/fixtures/dictionaries/*.zip "$OUT/dictionaries/"

# Skip the work when every fixture exists and is newer than this script.
fresh=1
for n in "${NAMES[@]}"; do
  if [[ ! -s "$OUT/$n" || "$SELF" -nt "$OUT/$n" ]]; then fresh=0; fi
done
if [[ $fresh -eq 1 ]]; then
  echo "Fixtures up to date: $OUT"
  exit 0
fi

mkdir -p "$OUT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/clipdeck-fixtures.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Subtitle sources (UTF-8, Japanese). Cue times: 1.0-2.5 s, 3.0-4.5 s, 5.0-6.5 s.
cat > "$WORK/sub.srt" <<'EOF'
1
00:00:01,000 --> 00:00:02,500
こんにちは、世界。

2
00:00:03,000 --> 00:00:04,500
これはテストです。

3
00:00:05,000 --> 00:00:06,500
さようなら。
EOF

cat > "$WORK/sub.ass" <<'EOF'
[Script Info]
ScriptType: v4.00+
PlayResX: 320
PlayResY: 180

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,16,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,2,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.50,Default,,0,0,0,,こんにちは、世界。
Dialogue: 0,0:00:03.00,0:00:04.50,Default,,0,0,0,,これはテストです。
Dialogue: 0,0:00:05.00,0:00:06.50,Default,,0,0,0,,さようなら。
EOF

# Sources. 24 fps, 320x180: a solid colour per second, and a beep at the start of each even second.
VIDEO_SRC="color=c=black:s=320x180:r=24,format=gbrp,geq=r='255*mod(floor(T),2)':g='255*mod(floor(T/2),2)':b='255*mod(floor(T/4),2)'"
AUDIO_SRC="aevalsrc=0.5*sin(2*PI*880*t)*lt(mod(t\,2)\,0.2):s=48000:d=8"
COMMON=(-hide_banner -loglevel error -y)

# Writes to a temp name first so a failed run never leaves a half-written fixture behind.
finish() { mv "$WORK/$1" "$OUT/$1"; echo "  $1"; }

echo "Generating fixtures in $OUT"

# 1. H.264 + B-frames, AAC stereo, SRT + ASS (Japanese).
n=${NAMES[0]}
ffmpeg "${COMMON[@]}" \
  -f lavfi -i "$VIDEO_SRC" -f lavfi -i "$AUDIO_SRC" -i "$WORK/sub.srt" -i "$WORK/sub.ass" \
  -map 0:v -map 1:a -map 2:s -map 3:s -t 8 \
  -c:v libx264 -bf 2 -pix_fmt yuv420p -g 24 \
  -c:a aac -ac 2 -b:a 96k \
  -c:s:0 srt -c:s:1 ass \
  -metadata:s:s:0 language=jpn -metadata:s:s:0 title=SRT \
  -metadata:s:s:1 language=jpn -metadata:s:s:1 title=Full \
  "$WORK/$n"
finish "$n"

# 2. HEVC Main10, open GOP, FLAC.
n=${NAMES[1]}
ffmpeg "${COMMON[@]}" \
  -f lavfi -i "$VIDEO_SRC" -f lavfi -i "$AUDIO_SRC" \
  -map 0:v -map 1:a -t 8 \
  -c:v libx265 -pix_fmt yuv420p10le -x265-params "open-gop=1:keyint=24:min-keyint=12:bframes=3:log-level=error" \
  -c:a flac -ac 2 \
  "$WORK/$n"
finish "$n"

# 3. Start offset: video at 1.0 s, audio delayed a further 0.5 s (1.5 s). AC-3 5.1, SRT.
n=${NAMES[2]}
ffmpeg "${COMMON[@]}" \
  -f lavfi -i "$VIDEO_SRC" -itsoffset 0.5 -f lavfi -i "$AUDIO_SRC" -i "$WORK/sub.srt" \
  -map 0:v -map 1:a -map 2:s -t 8 \
  -output_ts_offset 1 \
  -c:v libx264 -bf 2 -pix_fmt yuv420p -g 24 \
  -c:a ac3 -ac 6 -b:a 384k \
  -c:s srt -metadata:s:s:0 language=jpn \
  "$WORK/$n"
finish "$n"

# 4. No subtitles, AAC 5.1.
n=${NAMES[3]}
ffmpeg "${COMMON[@]}" \
  -f lavfi -i "$VIDEO_SRC" -f lavfi -i "$AUDIO_SRC" \
  -map 0:v -map 1:a -t 8 \
  -c:v libx264 -pix_fmt yuv420p -g 24 \
  -c:a aac -ac 6 -b:a 256k \
  "$WORK/$n"
finish "$n"

# 5. H.264 High 10 (10-bit): the importer must reject this.
n=${NAMES[4]}
ffmpeg "${COMMON[@]}" \
  -f lavfi -i "$VIDEO_SRC" -f lavfi -i "$AUDIO_SRC" \
  -map 0:v -map 1:a -t 8 \
  -c:v libx264 -profile:v high10 -pix_fmt yuv420p10le -g 24 \
  -c:a aac -ac 2 -b:a 96k \
  "$WORK/$n"
finish "$n"

echo "Fixtures ready: $OUT"
