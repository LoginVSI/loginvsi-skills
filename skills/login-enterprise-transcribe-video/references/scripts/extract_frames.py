#!/usr/bin/env python3
"""
extract_frames.py — Turn a screen-recording video into a small set of key frames
plus a manifest, ready for an AI to read and convert into natural-language steps.

Strategy: we don't want every frame (a 3-minute clip at 30fps is 5400 frames).
We want the *moments that matter* — when the screen meaningfully changes, e.g. a
menu opens, a page navigates, a dialog appears. We get those two ways and merge:

  1. Scene-change detection (ffmpeg's `scene` score) — catches abrupt visual
     changes like clicks that open menus or navigate to a new view.
  2. A steady interval sample — catches slow changes (typing, scrolling) that a
     scene threshold would miss, and guarantees coverage of long static stretches.

We then de-duplicate timestamps that are too close together, always keep the
first and last frame for context, and cap the total so the AI isn't flooded.

Output:
  <out>/frames/frame_0001_t0.0s.png, ...   (the key frames, in order)
  <out>/manifest.json                       (index, timestamp, filename, source)

Requires: ffmpeg + ffprobe on PATH.

Usage:
  python extract_frames.py VIDEO [--out DIR] [--scene-threshold 0.30]
         [--interval 4.0] [--min-gap 1.0] [--max-frames 40] [--width 1280]
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 and r.stderr:
        print(f"Warning: command failed (exit {r.returncode}): {' '.join(cmd)}", file=sys.stderr)
        print(f"  stderr: {r.stderr.strip()[:500]}", file=sys.stderr)
    return r


def check_tools(ffmpeg_path=None, ffprobe_path=None):
    ffmpeg = ffmpeg_path or shutil.which("ffmpeg")
    ffprobe = ffprobe_path or shutil.which("ffprobe")
    if not ffmpeg:
        print("ERROR: ffmpeg not found.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Possible causes:", file=sys.stderr)
        print("  1. ffmpeg is not installed:", file=sys.stderr)
        print("       Windows: winget install Gyan.FFmpeg", file=sys.stderr)
        print("       macOS:   brew install ffmpeg", file=sys.stderr)
        print("       Ubuntu:  sudo apt install ffmpeg", file=sys.stderr)
        print("  2. ffmpeg is installed but not on this process's PATH.", file=sys.stderr)
        print("     Try: --ffmpeg /path/to/ffmpeg --ffprobe /path/to/ffprobe", file=sys.stderr)
        print("  3. PATH was modified after this shell/agent started.", file=sys.stderr)
        print("     Try restarting your terminal or agent.", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"Current PATH: {os.environ.get('PATH', '(not set)')}", file=sys.stderr)
        sys.exit(1)
    if not ffprobe:
        print("ERROR: ffprobe not found. It is usually included with ffmpeg.", file=sys.stderr)
        print("  Try: --ffprobe /path/to/ffprobe", file=sys.stderr)
        print(f"Current PATH: {os.environ.get('PATH', '(not set)')}", file=sys.stderr)
        sys.exit(1)
    return ffmpeg, ffprobe


def get_duration(video, ffprobe_bin="ffprobe"):
    r = run([
        ffprobe_bin, "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", video,
    ])
    try:
        return float(r.stdout.strip())
    except ValueError:
        sys.exit(f"ERROR: could not read duration of {video}.\n{r.stderr}")


def scene_timestamps(video, threshold, ffmpeg_bin="ffmpeg"):
    """Return timestamps (seconds) where the scene score exceeds threshold."""
    r = run([
        ffmpeg_bin, "-i", video,
        "-vf", f"select='gt(scene,{threshold})',showinfo",
        "-vsync", "vfr", "-f", "null", "-",
    ])
    # showinfo writes to stderr; lines contain `pts_time:12.345`
    return [float(m) for m in re.findall(r"pts_time:([0-9.]+)", r.stderr)]


def interval_timestamps(duration, interval):
    ts, t = [], 0.0
    while t < duration:
        ts.append(round(t, 3))
        t += interval
    return ts


def dedupe(timestamps, min_gap):
    out = []
    for t in sorted(timestamps):
        if not out or (t - out[-1]) >= min_gap:
            out.append(t)
    return out


def cap(timestamps, max_frames):
    """Evenly thin the list to at most max_frames, keeping first and last."""
    n = len(timestamps)
    if n <= max_frames:
        return timestamps
    step = n / max_frames
    idx = sorted({min(int(i * step), n - 1) for i in range(max_frames)})
    kept = [timestamps[i] for i in idx]
    if timestamps[-1] not in kept:
        kept[-1] = timestamps[-1]
    return kept


def extract_one(video, t, path, width, ffmpeg_bin="ffmpeg"):
    # -ss before -i = fast seek; re-decode a single frame at timestamp t.
    vf = f"scale={width}:-2" if width else "scale=iw:ih"
    r = run([
        ffmpeg_bin, "-y", "-ss", f"{t}", "-i", video,
        "-frames:v", "1", "-vf", vf, path,
    ])
    return os.path.exists(path) and os.path.getsize(path) > 0, r.stderr


def main():
    ap = argparse.ArgumentParser(description="Extract key frames from a screen recording.")
    ap.add_argument("video")
    ap.add_argument("--out", default="frames_out")
    ap.add_argument("--scene-threshold", type=float, default=0.30,
                    help="0-1; lower = more sensitive to change (default 0.30)")
    ap.add_argument("--interval", type=float, default=4.0,
                    help="seconds between steady-sample frames (default 4.0)")
    ap.add_argument("--min-gap", type=float, default=1.0,
                    help="merge frames closer than this many seconds (default 1.0)")
    ap.add_argument("--max-frames", type=int, default=40,
                    help="hard cap on number of frames (default 40)")
    ap.add_argument("--width", type=int, default=1280,
                    help="resize frame width in px, keeps aspect (0 = original)")
    ap.add_argument("--ffmpeg", default=None,
                    help="Explicit path to ffmpeg binary (use when ffmpeg is installed but not on PATH)")
    ap.add_argument("--ffprobe", default=None,
                    help="Explicit path to ffprobe binary (use when ffprobe is installed but not on PATH)")
    args = ap.parse_args()

    ffmpeg_bin, ffprobe_bin = check_tools(
        ffmpeg_path=args.ffmpeg, ffprobe_path=args.ffprobe
    )
    if not os.path.isfile(args.video):
        sys.exit(f"ERROR: video not found: {args.video}")

    duration = get_duration(args.video, ffprobe_bin=ffprobe_bin)
    frames_dir = os.path.join(args.out, "frames")
    os.makedirs(frames_dir, exist_ok=True)

    scene = scene_timestamps(args.video, args.scene_threshold, ffmpeg_bin=ffmpeg_bin)
    interval = interval_timestamps(duration, args.interval)

    tagged = {round(t, 3): "scene" for t in scene}
    for t in interval:
        tagged.setdefault(round(t, 3), "interval")
    tagged.setdefault(0.0, "interval")
    last = round(max(duration - 0.1, 0.0), 3)
    tagged.setdefault(last, "interval")

    chosen = cap(dedupe(list(tagged), args.min_gap), args.max_frames)

    manifest = {
        "video": os.path.abspath(args.video),
        "duration_seconds": round(duration, 2),
        "frame_count": 0,
        "scene_threshold": args.scene_threshold,
        "frames": [],
    }

    idx = 0
    for t in chosen:
        idx += 1
        fname = f"frame_{idx:04d}_t{t:.1f}s.png"
        fpath = os.path.join(frames_dir, fname)
        ok, err = extract_one(args.video, t, fpath, args.width, ffmpeg_bin=ffmpeg_bin)
        if not ok:
            print(f"Warning: failed to extract frame at {t}s: {err.strip()[:300] if err else 'no output file produced'}", file=sys.stderr)
            idx -= 1
            continue
        manifest["frames"].append({
            "index": idx,
            "timestamp_seconds": round(t, 2),
            "timestamp_label": f"{int(t)//60:02d}:{t%60:05.2f}",
            "file": os.path.join("frames", fname),
            "source": tagged.get(round(t, 3), "interval"),
        })

    manifest["frame_count"] = len(manifest["frames"])
    with open(os.path.join(args.out, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Extracted {manifest['frame_count']} key frames from "
          f"{duration:.1f}s of video.")
    print(f"  Frames:   {frames_dir}")
    print(f"  Manifest: {os.path.join(args.out, 'manifest.json')}")
    if manifest["frame_count"] == 0:
        sys.exit("ERROR: no frames extracted — check the video file and ffmpeg.")


if __name__ == "__main__":
    main()
