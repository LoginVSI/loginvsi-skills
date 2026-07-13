---
name: login-enterprise-transcribe-video
description: Watch a screen-recording video and turn it into written, step-by-step documentation of what the user did in an application. Use this whenever someone hands you a screen recording (.mp4/.mov/.webm/.mkv) and wants the on-screen actions described in plain English — e.g. "document the steps in this recording", "turn this screencast into a how-to / SOP / runbook", "write instructions from this demo video", "what does the person do in this video", or "convert this walkthrough into a tutorial". This does NOT control the computer or replay actions; it only observes a recording and describes the navigation and interactions it sees. Trigger eagerly whenever a video shows someone using software and the goal is a written procedure.
license: Apache-2.0
compatibility: >-
  Requires Python 3, ffmpeg/ffprobe on PATH. Works on any platform
  for transcription. Screen capture requires Windows.
metadata:
  author: loginvsi
  version: "1.0"
---

# Video to Steps

Convert a screen-recording video into clear, ordered, natural-language steps describing how the person navigated and interacted with the application — plus a short summary and the relevant screenshots.

You (the AI) can't scrub through a video frame by frame, but you *can* look at images. So the trick is simple: pull a small set of meaningful frames out of the video, look at them in order, and narrate the workflow. A bundled script does the frame extraction; your job is the seeing and the writing.

## When to use this

Anytime the input is a recording of someone using software and the desired output is a written procedure: how-to guides, SOPs, runbooks, onboarding docs, bug-repro steps, "what did this person click" analyses, or tutorial drafts. It works on standard screen captures (QuickTime, Loom, OBS, Zoom recordings, etc.).

It is **observational only** — it documents what's in the recording. It does not operate the user's computer.

## Requirements

`ffmpeg` and `ffprobe` must be on PATH (macOS: `brew install ffmpeg`; Ubuntu: `sudo apt install ffmpeg`). The script checks and tells the user if they're missing.

## Workflow

### 1. Locate the video and pick an output folder

Confirm the path to the recording. Choose a working folder for results (the user's selected folder if there is one, otherwise the outputs directory). Call it `<OUT>` below.

### 2. Extract key frames

Run the bundled script. It samples scene-change moments (menus opening, page navigations) plus a steady interval (to catch typing/scrolling), de-duplicates, and caps the count so you get a digestible set rather than thousands of frames.

```bash
python3 <skill_dir>/scripts/extract_frames.py "<VIDEO>" --out "<OUT>"
```

Useful knobs (defaults are sensible — only reach for these if the first pass is too sparse or too noisy):

- `--scene-threshold 0.30` — lower (e.g. `0.15`) catches subtler changes; raise it if you get near-identical frames.
- `--interval 4.0` — seconds between steady samples; lower for fast-moving or dense workflows.
- `--max-frames 40` — hard cap; raise for long recordings.
- `--width 1280` — frame width in px; raise for tiny UI text, set `0` for original.

The script writes `<OUT>/frames/` and `<OUT>/manifest.json` (each frame's index, timestamp, filename, and whether it came from a scene change or the interval sample).

### 3. Read the frames in order

Read `<OUT>/manifest.json`, then view the frames **in timestamp order** with the Read tool. As you go, build a mental model of the workflow:

- What application/screen is shown, and what is the person trying to accomplish?
- At each meaningful change: what did they click, type, open, select, or navigate to? Name the concrete UI element ("the **File** menu", "the **Search** box", "the blue **Save** button in the top-right"), not just "they clicked something".
- Infer the action that caused a change between two frames. If frame A shows a closed menu and frame B shows it open, the step is "Click the X menu." Read visible text, field values, and titles to ground each step.
- Ignore noise: cursor jitter, identical frames, or transient redraws aren't steps. Several frames may collapse into one step, or one frame may imply two.
- If something is genuinely ambiguous (you can't tell what was clicked), say so briefly rather than inventing detail.

Frames are sampled, so exact keystrokes or split-second clicks can be missed. Describe what the evidence supports; flag uncertainty rather than fabricating.

### 4. Write the documentation

Produce a Markdown file at `<OUT>/<name>-steps.md` with this structure:

```markdown
# <Title — what this workflow accomplishes>

## Summary
<2-4 sentences: the application, the goal of the workflow, and the outcome.>

## Steps

### Step 1 — <short imperative title>
<What the person does and why, in plain English. Reference concrete UI elements and any visible text/values typed.>

![Step 1](frames/frame_0001_t0.0s.png)

### Step 2 — <short imperative title>
...
```

Guidelines for good steps:

- One action per step, in imperative voice ("Click…", "Type…", "Select…", "Navigate to…"). This reads as instructions someone could follow, not just a play-by-play.
- Pair each step with the most representative frame using a **relative** image path (`frames/<file>`) so the screenshots travel with the document.
- Merge redundant frames; not every extracted frame deserves its own step. Aim for the natural number of steps a human would write — often fewer than the number of frames.
- Keep the summary focused on intent and outcome so a reader knows what they're about to learn before the details.
- If a `--width` of original or higher resolution would help the reader see small UI text, regenerate; legible screenshots matter for a how-to.

### 5. Deliver

Save the Markdown (and keep the `frames/` folder alongside it so images resolve). If a `present_files` tool is available, present the `.md` file. Offer to also export to Word/PDF or to re-run with different sampling if the user wants finer or coarser granularity.

## Tips on sampling

- **Too few steps / missed actions?** Lower `--scene-threshold` (to ~0.15) and/or `--interval` (to ~2), and raise `--max-frames`.
- **Too many near-identical frames?** Raise `--scene-threshold` (to ~0.4) and `--min-gap`.
- **Tiny or blurry UI text?** Raise `--width` (e.g. `1920`) or set `--width 0` for the original resolution, then re-read the frames.
- **Very long recording?** Raise `--max-frames`, or run the script on a trimmed clip if only part is relevant (`ffmpeg -ss START -to END -i in.mp4 -c copy clip.mp4`).
