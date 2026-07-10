# Automatic License Plate Recognition (ALPR) for Egyptian Plates

**ECE 228 — Image Processing | Zagazig University, Faculty of Engineering**
**Electronics and Communications Engineering Department | Group 5**

Classical image processing pipeline that detects and reads Egyptian license plates from car photographs — simulating a radar-style traffic camera. Built entirely with MATLAB using classical computer vision techniques: **no deep learning, no neural networks, no pre-trained models, no OCR libraries.**

---

## Overview

Given a raw photo of a car (taken from a fixed camera height and angle, like a traffic camera would capture), the system:

1. Detects and localizes the license plate region
2. Corrects tilt and crops it to a clean, standardized image
3. Segments individual characters (Arabic letters + Eastern Arabic digits)
4. Recognizes each character using template matching
5. Outputs the full plate string, e.g. `ra seen waw | 0 4 9 6`

The pipeline was built and tested on a self-collected dataset of 50 real Egyptian car photos.

---

## Results

| Metric | Result |
|---|---|
| **Plate Detection Accuracy** | 86% (43 / 50 images) |
| **Character Recognition Accuracy** | 87.5% |
| **Full Plate Match Accuracy*** | 100% (on a cleaned subset) |
| **Overall Accuracy** | 68% |

*\*Full plate exact match was measured on a subset of clearly-captured plates; overall accuracy accounts for the full dataset including harder cases (faded plates, extreme angles).*

**Known limitations:**
- **Faded / low-contrast plates** — segmentation struggles when characters aren't clearly separated from the background
- **Steep camera angles** — non-zero tilt distorts character shapes enough to confuse template matching in some cases

---

## Repository Structure

```
.
├── Dataset/          # 50 raw car images (img_001.jpg ... img_050.jpg)
├── Docs/             # Project spec, presentation, written report
├── Results/          # Pipeline outputs: annotated images, crops, figures, ocr_results.csv
├── src/              # All MATLAB source code
│   ├── main.m                  # Run the full pipeline on a single image
│   ├── plate_rec_v2.m          # Stage 1 — plate detection & localization
│   ├── enhance_plate.m         # Stage 1.5 — deskewing & standardization
│   ├── recognize_plate.m       # Stage 2 — character segmentation & recognition
│   ├── build_templates.m       # Interactive tool to build the character template library
│   ├── run_stage1_outputs.m    # Batch: full Stage 1 deliverables for all 50 images
│   ├── run_stage1_batch.m      # Batch: quick Stage 1 accuracy + montage
│   └── run_stage2.m            # Batch: OCR + accuracy report (needs ground truth filled in)
├── templates/        # Character template library (28 classes, 40×40 px PNGs)
└── README.md
```

> **Note on the dataset:** all 50 images are included in this repo for reproducibility. If you're cloning this for reference and don't need the raw photos, feel free to skip downloading the `Dataset/` folder.

---

## Pipeline

```
Raw car photo
      │
      ▼
┌─────────────────────────────┐
│   STAGE 1 — Detection       │   plate_rec_v2.m
│   Locate the plate region   │
└────────────┬────────────────┘
             │ bounding box + raw crop
             ▼
┌─────────────────────────────┐
│   STAGE 1.5 — Enhancement   │   enhance_plate.m
│   Deskew & standardize      │
└────────────┬────────────────┘
             │ clean 440×200 plate image
             ▼
┌─────────────────────────────┐
│   STAGE 2 — Recognition     │   recognize_plate.m
│   Segment & match chars     │
└────────────┬────────────────┘
             │
             ▼
   "ra seen waw | 0 4 9 6"
```

### Stage 1 — Plate Detection
Applies CLAHE contrast enhancement and Sobel edge detection (prioritizing vertical edges, since Arabic characters are stroke-heavy), then filters candidate regions using geometry (aspect ratio, position, size). Every Egyptian plate has a **blue header band** — the single most reliable signal — so candidates are verified in HSV space for blue pixel ratio, then scored on 8 weighted heuristics (edge density, aspect ratio fit, contrast, position, brightness, etc).

### Stage 1.5 — Enhancement
Raw crops are often tilted and inconsistently sized. This stage detects the blue band's orientation, rotates the image to straighten it, then tightly crops and resizes every plate to a standard 440×200 image.

### Stage 2 — Character Recognition
Locates the plate's white body, tries 5 binarization strategies and picks the best one, removes the vertical divider between letters and digits, merges dot marks into their parent character (for letters like ق and ي), then matches each segmented character against a template library (28 classes: 18 Arabic letters + 10 digits) using normalized cross-correlation.

---

## How to Run

**Full pipeline on a single image:**
```matlab
% Edit the imageName variable at the top of main.m, then run:
main
```

**Full batch (all 50 images) — produces every deliverable:**
```matlab
run_stage1_outputs   % Detection + enhancement + annotated figures for all images
build_templates       % Run once to build/expand your character template library
run_stage2            % Fill in ground truth inside this script, then run for OCR + accuracy
```

**Debug a single stage:**
```matlab
[bbox, rawCrop, ~] = plate_rec_v2('Dataset/img_001.jpg', true);
enhanced = enhance_plate(rawCrop);
[text, ~, ~] = recognize_plate(enhanced, 'templates', true);
disp(text)
```

---

## Dataset

- 50 images of real Egyptian cars, collected by the team (no images downloaded from the internet)
- Smartphone camera, 1.0–1.5 m height, 15°–30° downward tilt, 3–8 m distance
- Daylight only, minimum 1080p resolution, no pre-editing
- Named `img_001.jpg` through `img_050.jpg`

---

**Course:** ECE 228 — Image Processing
**Institution:** Zagazig University, Faculty of Engineering
**Submitted:** May 2026

---