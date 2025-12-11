# Monitoring and Hybrid OCR Changes

**Date**: 2025-12-10  
**Author**: Augment Agent

---

## Overview

This document describes the enhancements made to the system monitoring and hybrid OCR functionality in the PaddleOCR backend.

---

## 1. Enhanced System Monitoring

### Problem
PaddleOCR's C++ engine runs silently for 60-90 seconds with no output, making it appear frozen. Users requested **real system data** (CPU, memory, disk I/O) instead of fabricated progress messages.

### Solution
Implemented a background monitoring thread that uses native Linux tools and `/proc` filesystem to collect and emit real system metrics every 3 seconds during OCR processing.

### Implementation Details

**File**: `backend/app.py`

**Function**: `monitor_ocr_process(stop_event, pixel_count, ocr_start_time)` (lines 581-696)

**Metrics Collected**:

1. **CPU Usage** (`/proc/[pid]/stat`)
   - Calculates CPU percentage from user time (utime) and system time (stime)
   - Example: `CPU: 93.5%`

2. **Memory Usage** (`/proc/[pid]/status`)
   - **VmRSS**: Physical RAM used (resident set size)
   - **VmSize**: Total virtual memory allocated
   - Example: `RAM: 3735MB (VmSize: 9697MB)`

3. **Thread Count** (`/proc/[pid]/status`)
   - Number of threads in the process
   - Example: `Threads: 32`

4. **Disk I/O** (`/proc/[pid]/io`)
   - Bytes read and written to disk
   - Shows model files being loaded
   - Example: `Disk I/O: 106MB read, 182MB written`

5. **Open Files** (`lsof -p [pid]`)
   - Model files (.pdparams, .pdiparams)
   - Regular files open
   - Network connections
   - Example: `6 model files | 45 files open | 2 network connections`

6. **System Load Average** (`/proc/loadavg`)
   - 1-minute and 5-minute load averages
   - Shows system-wide activity
   - Example: `System load: 13.90 (1min), 8.79 (5min)`

**Log Format**:
```
[REAL DATA] 126.3s | CPU: 94.3% | RAM: 3273MB (VmSize: 9697MB) | Threads: 31
[REAL DATA] Disk I/O: 23MB read, 182MB written
[REAL DATA] 6 model files | 45 files open | 2 network connections
[REAL DATA] System load: 14.00 (1min), 8.64 (5min)
```

**Integration Points**:
- `/ocr` endpoint (lines 1087-1117): Monitors PaddleOCR processing
- `/ocr/hybrid` endpoint (lines 1346-1376): Monitors PaddleOCR fallback processing

**Dependencies**:
- `lsof` package (installed in Dockerfile)
- `procps` package (installed in Dockerfile)

---

## 2. Hybrid OCR with Tesseract Result Inclusion

### Problem
When Tesseract confidence is low (< 0.85), the system falls back to PaddleOCR but discards the Tesseract result. Users wanted to see **both results** even when Tesseract confidence is low.

### Solution
Modified the `/ocr/hybrid` endpoint to include Tesseract results in the response even when falling back to PaddleOCR.

### Implementation Details

**File**: `backend/app.py`

**Endpoint**: `/ocr/hybrid` (lines 1230-1450)

**Changes**:

1. **Store Tesseract Result** (lines 1302-1312)
   - Capture Tesseract result in a dictionary before decision logic
   - Includes: engine, confidence, processing_time, blocks, raw_text, block_count

2. **Include in High-Confidence Response** (lines 1314-1340)
   - When Tesseract confidence >= 0.85, include `tesseract_result` in response
   - User sees the same result that was used

3. **Include in PaddleOCR Fallback Response** (lines 1435-1441)
   - When falling back to PaddleOCR, check if `tesseract_result` exists
   - If available, include it in the response alongside PaddleOCR result
   - Log: `[HYBRID] Including Tesseract result in response (confidence: 0.48)`

**Response Structure** (when falling back to PaddleOCR):
```json
{
  "success": true,
  "filename": "IMG_0372.jpg",
  "engine": "paddleocr",
  "confidence": 0.98,
  "processing_time": 206.7,
  "blocks": [...],  // PaddleOCR blocks (132)
  "raw_text": "...",  // PaddleOCR text
  "parsed": {...},
  "layout": {...},
  "tesseract_result": {
    "engine": "tesseract",
    "confidence": 0.48,
    "processing_time": 24.1,
    "blocks": [...],  // Tesseract blocks (474)
    "raw_text": "...",  // Tesseract text
    "block_count": 474
  }
}
```

**Benefits**:
- Users can compare results from both engines
- Tesseract may catch text that PaddleOCR misses (or vice versa)
- Provides transparency into the hybrid decision-making process
- Useful for debugging and quality assessment

---

## 3. Testing Results

**Test Image**: `IMG_0372.jpg` (3024x4032 pixels, 2.6MB)

**Processing Times**:
- Preprocessing: 23.2s
- Tesseract: 24.1s (474 blocks, confidence: 0.48)
- PaddleOCR: 158.2s (132 blocks, confidence: 0.98)
- **Total**: 206.7s

**System Metrics Observed**:
- CPU: 37% - 99% (average ~70%)
- RAM: 765MB → 3735MB peak → 1425MB final
- Disk I/O: 5MB → 106MB read (model loading)
- Threads: 21 → 32
- System load: 8.04 → 14.88 peak

**Result**:
- Primary engine: PaddleOCR (high confidence)
- Secondary result: Tesseract (included for comparison)
- Both results available in JSON response

---

## 4. Frontend Integration

**File**: `src/App.tsx` (lines 100-120)

The frontend already handles `[REAL DATA]` logs:
```typescript
if (msg.includes('[REAL DATA]')) {
  type = 'ocr';  // Color-coded as OCR activity
}
```

System monitoring logs are streamed to the frontend via Server-Sent Events (SSE) and displayed in real-time.

---

## 5. Metric Interpretation Guide

Understanding what each metric indicates:

| Metric | What It Means | Normal Range | Concern Threshold |
|--------|---------------|--------------|-------------------|
| **CPU %** | Processor utilization during OCR | 70-100% | < 20% (I/O bottleneck) |
| **VmRSS** | Physical RAM actually used | 700MB - 4GB | > 6GB (OOM risk) |
| **VmSize** | Total virtual memory allocated | 2GB - 10GB | > 12GB (fragmentation) |
| **Threads** | Parallel processing threads | 21-32 | > 50 (thread leak) |
| **Disk I/O** | Model files being loaded | 5MB - 150MB | > 1GB (reload bug) |
| **System Load** | System-wide CPU queue depth | 8-15 (8-core) | > cores × 3 |
| **Open Files** | File descriptors in use | 40-60 | > 1000 (leak) |

### Diagnostic Scenarios

**Scenario 1: CPU < 20% during OCR**
- **Cause**: I/O wait or thread starvation
- **Action**: Check disk I/O, verify model files are cached

**Scenario 2: VmRSS > 6GB**
- **Cause**: Memory leak or large image
- **Action**: Check image size, restart backend, investigate memory leak

**Scenario 3: Disk I/O > 500MB**
- **Cause**: Model files reloading on every request
- **Action**: Verify model caching, check file system performance

**Scenario 4: System Load > 24 (on 8-core)**
- **Cause**: System overload, too many concurrent requests
- **Action**: Reduce concurrency, add rate limiting

---

## 6. Alert Conditions

Recommended monitoring alerts:

| Condition | Severity | Action |
|-----------|----------|--------|
| VmRSS > 6GB | Warning | Check for memory leak |
| VmRSS > 8GB | Critical | Restart backend to prevent OOM |
| CPU < 20% for > 30s during OCR | Warning | Check I/O bottleneck |
| Disk I/O > 1GB | Critical | Investigate model reload bug |
| System Load > cores × 3 | Warning | Reduce load |
| Open Files > 1000 | Critical | File descriptor leak |
| Processing Time > 300s | Warning | Performance degradation |

---

## 7. Limitations and Known Issues

### Current Limitations

1. **Single Process Monitoring**: Only monitors the main OCR process, not worker pools or GPU processes
2. **No GPU Metrics**: Does not track GPU usage (if GPU available)
3. **Fixed Interval**: Monitoring interval is hardcoded to 3 seconds
4. **No Historical Data**: Metrics are logged but not stored for trend analysis
5. **Linux Only**: Uses `/proc` filesystem, not portable to Windows/macOS

### Performance Considerations

1. **Memory Spikes**: PaddleOCR can spike to 4GB+ RAM, may cause OOM on 2GB devices
2. **Disk I/O**: First request loads ~100MB of model files, subsequent requests should be cached
3. **Processing Time**: 150-200s total is normal for 3024x4032 images
4. **Hybrid Overhead**: Tesseract adds ~25s overhead even when falling back to PaddleOCR

### Optimization Opportunities

1. **Model Preloading**: Load PaddleOCR models at startup to avoid first-request delay
2. **Image Downscaling**: Resize large images (> 4MP) to reduce processing time
3. **ONNX Runtime**: Convert PaddleOCR to ONNX for 30-70% speedup
4. **Batch Processing**: Process multiple images in one request
5. **GPU Acceleration**: Use CUDA/TensorRT for 10x speedup (requires GPU)

---

## 8. Future Enhancements

### Monitoring Improvements
1. Add network I/O monitoring
2. Track GPU usage (if GPU available)
3. Show process tree (parent/child processes)
4. Add memory breakdown (heap, stack, shared)
5. Monitor temperature sensors (CPU/GPU)
6. Add configurable monitoring interval
7. Export metrics to Prometheus/Grafana
8. Store metrics in time-series database for trend analysis

### Multi-Process Support
- Monitor worker pools
- Track GPU processes separately
- Monitor web server parent process
- Aggregate metrics across multiple backends

---

## References

- User preference: "User prefers real system data (CPU, memory, I/O) over fabricated progress messages"
- Linux `/proc` filesystem documentation: https://man7.org/linux/man-pages/man5/proc.5.html
- `lsof` man page: https://man7.org/linux/man-pages/man8/lsof.8.html
- PaddleOCR documentation: https://github.com/PaddlePaddle/PaddleOCR

