# youtube-djjer321

## Extracting frames in CMD/PowerShell (Windows 11)

```powershell
# Make an output folder (no error if it exists)
mkdir frames 2>$null

# Extract the WHOLE video, saving ONE PNG every 30 frames
ffmpeg -y -i "in.mp4" -vf "select=not(mod(n\,30))" -vsync vfr -frame_pts 1 "frames/frame_%06d.png"
```

## Extracting frames in git bash (Windows 11)

```bash
# this gets bash syntax highlighting
mkdir -p frames
ffmpeg -i in.mp4 -vf "select='not(mod(n,30))'" -vsync vfr frames/%06d.png
# extract the FIRST 5 minutes, saving ONE PNG every 30 frames
ffmpeg -y -i "in.mp4" -t 00:05:00 -vf "select=not(mod(n\,30))" -vsync vfr -frame_pts 1 "frames/frame_%06d.png"
```
