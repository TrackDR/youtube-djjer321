#!/usr/bin/env bash
set -euo pipefail

IN="in.mp4"
OUT="out_1080x1920.mp4"
FPS=30
worig=1280; horig=720

# yokai watch 1 and 2
# Crops measured from your capture (w:h:x:y using inclusive coords resolved already)
#TOPCROP="crop=834:500:0:0"
#BOTCROP="crop=444:334:836:386"
#x1=0;   y1=0;   w1=834; h1=500
#x2=836; y2=386; w2=$((worig - x2)); h2=$((horig - y2))
#TOPCROP="crop=$w1:$h1:$x1:$y1"
#BOTCROP="crop=$w2:$h2:$x2:$y2"

# puyo puyo tetris jp
#TOPCROP="crop=838:500:0:0"
#BOTCROP="crop=w:h:838:392"
x1=0;   y1=0;   w1=838; h1=500
x2=838; y2=392; w2=$((worig - x2)); h2=$((horig - y2))
TOPCROP="crop=$w1:$h1:$x1:$y1"
BOTCROP="crop=$w2:$h2:$x2:$y2"

# mario kart 7 3ds
#TOPCROP="crop=834:500:0:0"
#BOTCROP="crop=w:h:836:386"
x1=0;   y1=0;   w1=834; h1=500
x2=836; y2=386; w2=$((worig - x2)); h2=$((horig - y2))
TOPCROP="crop=$w1:$h1:$x1:$y1"
BOTCROP="crop=$w2:$h2:$x2:$y2"

# snack world trejarers 3ds
#TOPCROP="crop=837:502:0:0"
#BOTCROP="crop=w:h:838:392"
x1=0;   y1=0;   w1=837; h1=502
x2=838; y2=392; w2=$((worig - x2)); h2=$((horig - y2))
TOPCROP="crop=$w1:$h1:$x1:$y1"
BOTCROP="crop=$w2:$h2:$x2:$y2"

# Placement on the 1080x1920 canvas
TOP_Y=75     # screen 1 (also used for layout 1)
BOT_Y=1022   # screen 2

export LC_ALL=C

pairs_file="$(mktemp)"
cat > "$pairs_file" <<'PAIRS'
000000 1
003480 2
011430 1
015300 2
015810 1
017700 2
020280 1
020520 2
021180 1
023520 2
023940 1
024720 2
025500 1
027150 2
032400 1
037410 2
039180 1
041250 2
041640 1
043260 2
045840 1
046050 2
046380 1
046980 2
047310 1
047820 2
048180 1
048660 2
066720 1
068280 2
068550 1
071700 2
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
  #for(i=0;i<n;i++) printf("[v%d][a%d]", i, i)
  #printf("concat=n=%d:v=1:a=1[outv][outa]\n", n)
  
  # NEW: concat to [cv][ca], then force CFR 30 on video
  for(i=0;i<n;i++) printf("[v%d][a%d]", i, i)
  printf("concat=n=%d:v=1:a=1[cv][ca];[cv]fps=%d[ov]\n", n, fps)

}
' "$pairs_file" > filter.txt

echo "filter.txt written ($(wc -c < filter.txt) bytes)"
head -n1 filter.txt

# Run ffmpeg (legacy script loader works on your build)
#ffmpeg -y -i "$IN" -filter_complex_script filter.txt -map "[outv]" -map "[outa]" \
#  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k "$OUT"
  
ffmpeg -y -i "$IN" -filter_complex_script filter.txt \
  -map "[ov]" -map "[ca]" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k -movflags +faststart "$OUT"


echo "Done -> $OUT"
rm -f "$pairs_file"
