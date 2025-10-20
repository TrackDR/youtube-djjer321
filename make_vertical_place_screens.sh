#!/usr/bin/env bash
set -euo pipefail

IN="in.mp4"
OUT="out_1080x1920.mp4"
FPS=30

# Crops measured from your capture (w:h:x:y using inclusive coords resolved already)
TOPCROP="crop=834:500:0:0"
BOTCROP="crop=444:334:836:386"

# Placement on the 1080x1920 canvas
TOP_Y=75     # screen 1 (also used for layout 1)
BOT_Y=1022   # screen 2

export LC_ALL=C

pairs_file="$(mktemp)"
cat > "$pairs_file" <<'PAIRS'
000000 2
003030 1
004410 2
006840 1
007830 2
008460 1
009360 2
010260 1
015450 2
016320 1
020550 2
023850 1
025830 2
030240 1
033870 2
034590 1
034830 2
035100 1
035760 2
036810 1
039030 2
042300 1
046230 2
049200 1
054690 2
056250 1
057330 2
066330 1
067650 2
069240 1
070440 2
073560 1
074790 2
078720 1
080190 2
PAIRS

# Build filter.txt
awk -v fps="$FPS" -v top="$TOPCROP" -v bot="$BOTCROP" -v topy="$TOP_Y" -v boty="$BOT_Y" '
BEGIN { n=0 }
NF>=2 { frames[n]=$1+0; mode[n]=$2+0; n++ }
END{
  for(i=0;i<n;i++){
    startf = frames[i]
    endf   = (i<n-1)?frames[i+1]:-1
    starts = startf / fps
    if(endf>=0) ends = endf / fps

    # ---- trim per segment (video) ----
    printf("[0:v]trim=")
    if(endf>=0) printf("%.3f:%.3f", starts, ends)
    else        printf("start=%.3f", starts)
    printf(",setpts=PTS-STARTPTS")

    if(mode[i]==1){
      # LAYOUT 1: place the single landscape frame at the SAME offset as screen 1 (y=topy)
      # scale to width 1080, make 1080x1920 black canvas, overlay at (x=0, y=topy)
      printf(",scale=1080:-2:flags=lanczos[sv%d];", i)
      printf("color=c=black:s=1080x1920,format=yuv420p[bg%d];", i)
      printf("[bg%d][sv%d]overlay=x=0:y=%d:shortest=1,setsar=1,format=yuv420p[v%d];", i, i, topy, i)
    } else {
      # LAYOUT 2: crop two screens, scale to 1080w, overlay TOP at y=topy and BOTTOM at y=boty
      printf(",split=2[v%da][v%db];", i, i)
      printf("[v%da]%s,scale=1080:-2:flags=lanczos[top%d];", i, top, i)
      printf("[v%db]%s,scale=1080:-2:flags=lanczos[bot%d];", i, bot, i)
      printf("color=c=black:s=1080x1920,format=yuv420p[bg%d];", i)
      printf("[bg%d][top%d]overlay=x=0:y=%d:shortest=1[tmp%d];", i, i, topy, i)
      printf("[tmp%d][bot%d]overlay=x=0:y=%d:shortest=1,setsar=1,format=yuv420p[v%d];", i, i, boty, i)
    }

    # ---- trim per segment (audio) ----
    printf("[0:a]atrim=")
    if(endf>=0) printf("%.3f:%.3f", starts, ends)
    else        printf("start=%.3f", starts)
    printf(",asetpts=PTS-STARTPTS[a%d];", i)
  }

  # concat with interleaved [v][a]
  for(i=0;i<n;i++) printf("[v%d][a%d]", i, i)
  printf("concat=n=%d:v=1:a=1[outv][outa]\n", n)
}
' "$pairs_file" > filter.txt

echo "filter.txt written ($(wc -c < filter.txt) bytes)"
head -n1 filter.txt

# Run ffmpeg (legacy script loader works on your build)
ffmpeg -y -i "$IN" -filter_complex_script filter.txt -map "[outv]" -map "[outa]" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k "$OUT"

echo "Done -> $OUT"
rm -f "$pairs_file"
