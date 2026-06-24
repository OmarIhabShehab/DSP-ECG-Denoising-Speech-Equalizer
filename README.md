# 🎛️ DSP Course Project — ECG Denoising & Multi-Band Speech Equalizer

<div align="center">

![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![MATLAB](https://img.shields.io/badge/Tool-MATLAB-orange?style=flat-square)
![DSP](https://img.shields.io/badge/Domain-Digital%20Signal%20Processing-brightgreen?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-success?style=flat-square)

**Two practical DSP systems — ECG signal denoising for telemedicine and a 7-band speech equalizer for podcast enhancement — implemented and validated in MATLAB.**

</div>

---

## 📁 Project Structure

```
DSP-Project/
│
├── Project_I_ECG_Denoising/       # ECG denoising MATLAB scripts & outputs
├── Project_II_Speech_Equalizer/   # Multi-band equalizer MATLAB scripts & outputs
├── Report/                         # Full technical report (PDF)
└── README.md
```

---

## 📌 Abstract

This project presents two DSP applications:

- **Project I** — ECG signal denoising using FIR and IIR digital filters applied to MIT-BIH arrhythmia database recordings, targeting baseline wander, power-line interference, and EMG noise.
- **Project II** — A 7-band speech equalizer for podcast enhancement with adjustable per-band gains, FIR/IIR filter options, and multi-rate output support.

---

## 🫀 Project I — ECG Signal Denoising

### Problem
ECG signals from the MIT-BIH Arrhythmia Database (360 Hz) are corrupted by three noise sources:

| Noise | Frequency | Cause |
|---|---|---|
| Baseline wander | < 0.5 Hz | Respiration & movement |
| Power-line interference | 50 Hz | Electrical equipment |
| EMG noise | 20–150 Hz | Muscle activity |

### Filter Pipeline

```
Raw ECG → HPF (0.5 Hz) → Notch (50 Hz) → LPF (100 Hz) → Clean ECG
```

### Designed Filters

| Filter | Type | Order | Cutoff | Attenuation |
|---|---|---|---|---|
| FIR Kaiser HPF | FIR (Kaiser) | 1000 | 0.5 Hz | ~44 dB |
| FIR Hamming HPF | FIR (Hamming) | 1000 | 0.5 Hz | ~41 dB |
| Butterworth HPF | IIR Butterworth | 4 | 0.5 Hz | 60 dB |
| Chebyshev HPF | IIR Cheby I | 4 | 0.5 Hz | 69 dB |
| Notch Filter | IIR Notch Q=25 | 2 | 50 Hz | 40.2 dB |
| Butterworth LPF | IIR Butterworth | 20 | 100 Hz | 47.9 dB |
| Chebyshev LPF | IIR Cheby I | 15 | 100 Hz | 86.1 dB |
| FIR Kaiser LPF | FIR (Kaiser) | 1000 | 100 Hz | 96.8 dB |

### Results
- All 4 filter pipelines achieved **~14.7–14.9 dB SNR improvement**
- Zero-phase filtering via `filtfilt()` — no time-shift in QRS complex
- High-order IIR filters implemented in **SOS form** for numerical stability

---

## 🎚️ Project II — Multi-Band Speech Equalizer

### Overview
A 7-band equalizer for podcast enhancement with:
- Per-band gain control (dB)
- FIR (Blackman window, order 80) and IIR (Butterworth, order 4) options
- Multi-rate output: original, 4x upsampled, 0.5x downsampled

### Frequency Bands

| Band | Range | Filter Type |
|---|---|---|
| 1 | 0 – 100 Hz | Low-pass |
| 2 | 100 – 300 Hz | Band-pass |
| 3 | 300 – 800 Hz | Band-pass |
| 4 | 800 – 2000 Hz | Band-pass |
| 5 | 2000 – 5000 Hz | Band-pass |
| 6 | 5000 – 10000 Hz | Band-pass |
| 7 | 10000 – 20000 Hz | High-pass |

### Signal Processing Pipeline
```
Input Audio
    → Band Splitting (7 filters)
    → Per-Band Gain Application
    → Reconstruction (Sum)
    → Normalization [-1, 1]
    → Output WAV files (x1, x4, x0.5 sample rates)
```

### Performance Metrics

| Metric | Original | Equalized |
|---|---|---|
| RMS Amplitude | 0.3147 | 0.3740 |
| Signal Power | -10.04 dBFS | -8.54 dBFS |
| Power Change | — | +1.50 dB |
| Correlation | — | 0.8906 |

### FIR vs IIR Trade-offs

| Property | FIR (Blackman) | IIR (Butterworth) |
|---|---|---|
| Phase | Linear ✅ | Non-linear ⚠️ |
| Order | 80 | 4 |
| Complexity | 560 mult/sample | 63 mult/sample |
| Stopband Attenuation | ~74 dB | ~24 dB |
| Real-time suitability | ❌ | ✅ |

---

## 🌐 Live Web Demos

Both projects are available as **interactive web-based applications**:

👉 [Google Drive — All outputs, plots, audio & web demos](https://drive.google.com/drive/folders/1FXF4M8ea4gsIbPnH7G7OFMAPYAb82hRU?usp=sharing)

---

## 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| MATLAB + Signal Processing Toolbox | Filter design & simulation |
| MIT-BIH Arrhythmia Database (PhysioNet) | ECG data source |
| MATLAB `filtfilt()` | Zero-phase filtering |
| MATLAB `resample()` | Multi-rate output |

---

## 👥 Team

| Name | ID |
|---|---|
| Omar Ihab Fared Abdo | 202401437 |
| Ahmed Hany Darwish | 202400731 |
| Abdullah Hossam | 202402212 |

Undergraduate project — Communications & Information Dept.
**University of Science and Technology, Zewail City**
Submission Date: 17 May 2026

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
