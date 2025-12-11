# Hybrid OCR System - Architecture Overview

**Date**: 2025-12-10  
**Version**: 1.0

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER LAYER                              │
├──────────────────────────┬──────────────────────────────────────┤
│   React Frontend         │      Flutter App                     │
│   (Web Browser)          │   (Native Mobile/Desktop)            │
│   Port 5173              │   Standalone                         │
│                          │                                      │
│   Features:              │   Features:                          │
│   - Web-based UI         │   - ML Kit (2-3s, offline)          │
│   - Real-time logs       │   - Tesseract (5-8s, offline)       │
│   - Backend-only OCR     │   - PaddleOCR (60-90s, optional)    │
│                          │   - SQLite storage                   │
│                          │   - Offline-first                    │
├──────────────────────────┴──────────────────────────────────────┤
│                    BACKEND LAYER                                │
│                                                                 │
│   PaddleOCR Backend (Port 5001)                                │
│   ├─ Tesseract OCR (5-8s, PSM 6)                               │
│   ├─ PaddleOCR (60-90s, PP-OCRv4)                              │
│   ├─ Hybrid Decision Logic (confidence thresholds)             │
│   ├─ Real-time System Monitoring (/proc, lsof)                │
│   └─ Result Comparison (include both results)                  │
│                                                                 │
│   PostgreSQL Database (Port 5432)                              │
│   └─ OCR results, user data, history                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## OCR Engine Cascade

### React Frontend Flow
```
User Upload
    ↓
Backend /ocr/hybrid
    ↓
Tesseract (5-8s)
    ├─ Confidence >= 85% → Return Tesseract result
    └─ Confidence < 85% → PaddleOCR (60-90s)
        └─ Return PaddleOCR + Tesseract results
```

### Flutter App Flow
```
User Capture/Select
    ↓
ML Kit (2-3s, on-device)
    ├─ Confidence >= 90% → Return ML Kit result
    └─ Confidence < 90% ↓
        Tesseract (5-8s, on-device)
            ├─ Confidence >= 85% → Return Tesseract result
            └─ Confidence < 85% ↓
                Backend Available?
                    ├─ Yes → PaddleOCR (60-90s, backend)
                    │        └─ Return PaddleOCR + Tesseract results
                    └─ No → Return best local result (ML Kit or Tesseract)
```

---

## Technology Stack

### Frontend Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **React Frontend** | Vite + React + TypeScript | Web-based UI |
| **Flutter App** | Flutter 3.x + Dart | Native mobile/desktop |
| **State Management** | React hooks / BLoC pattern | UI state |
| **HTTP Client** | Fetch API / http package | Backend communication |

### Backend Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Web Framework** | Flask 3.0 | REST API |
| **OCR Engines** | Tesseract 5.x, PaddleOCR 2.7 | Text recognition |
| **Database** | PostgreSQL 15 | Data persistence |
| **Monitoring** | /proc, lsof, psutil | System metrics |
| **Containerization** | Docker + Docker Compose | Deployment |

### Mobile OCR Engines (Flutter)

| Engine | Speed | Accuracy | Offline | Platform |
|--------|-------|----------|---------|----------|
| **ML Kit** | 2-3s | Good | ✅ | Android, iOS |
| **Tesseract** | 5-8s | Better | ✅ | All platforms |
| **PaddleOCR** | 60-90s | Best | ❌ | Backend only |

---

## Data Flow

### 1. React Frontend → Backend
```
1. User uploads image via web UI
2. Frontend sends POST /ocr/hybrid with image file
3. Backend runs Tesseract → PaddleOCR cascade
4. Backend streams real-time monitoring logs via SSE
5. Frontend displays results with both Tesseract and PaddleOCR data
```

### 2. Flutter App → Local OCR
```
1. User captures/selects image
2. App tries ML Kit (2-3s)
3. If confidence < 90%, tries Tesseract (5-8s)
4. If confidence >= 85%, saves to SQLite and displays
5. User sees result immediately (offline)
```

### 3. Flutter App → Backend
```
1. User captures/selects image
2. App tries ML Kit → Tesseract (both fail confidence checks)
3. App checks backend availability
4. If available, sends POST /ocr/hybrid
5. Backend runs PaddleOCR (60-90s)
6. App receives PaddleOCR + Tesseract results
7. App saves to SQLite and displays both results
```

---

## Key Design Principles

### 1. Offline-First (Flutter)
- Local OCR engines (ML Kit, Tesseract) work without internet
- SQLite database stores results locally
- Backend is optional enhancement, not requirement

### 2. Real System Data (Backend)
- No fabricated progress messages
- Actual CPU, RAM, disk I/O metrics from /proc
- Transparent monitoring during silent PaddleOCR processing

### 3. Result Transparency
- Users see results from multiple engines
- Tesseract result included even when using PaddleOCR
- Confidence scores displayed for comparison

### 4. Smart Cascade
- Fast engines first (ML Kit 2-3s)
- Fallback to slower, more accurate engines
- Confidence thresholds determine cascade progression

### 5. Dual Frontend Choice
- React for web-based access (no installation)
- Flutter for native mobile/desktop (offline capability)
- Both share same backend API

---

## Performance Characteristics

### Processing Times

| Path | Engines | Time | Success Rate |
|------|---------|------|--------------|
| **Fast** | ML Kit only | 2-3s | ~90% (Flutter) |
| **Medium** | Tesseract only | 5-8s | ~8% (Flutter) |
| **Slow** | Tesseract + PaddleOCR | 65-98s | ~2% (all) |
| **Web** | Tesseract + PaddleOCR | 65-98s | 100% (React) |

### Resource Usage (Backend)

| Metric | Idle | Processing | Peak |
|--------|------|------------|------|
| **CPU** | 5% | 70-100% | 100% |
| **RAM** | 700MB | 2-4GB | 4GB |
| **Disk I/O** | 0MB | 5-150MB | 150MB |
| **Threads** | 21 | 31-32 | 32 |

---

## Security Considerations

### Authentication
- Currently: No authentication (development)
- Recommended: Add JWT tokens, API keys, or OAuth

### Data Privacy
- Images processed in memory, not stored permanently (backend)
- Flutter app stores results locally in SQLite (user device only)
- No cloud sync by default (privacy-first)

### Input Validation
- File type validation (JPEG, PNG, HEIC)
- File size limits (< 10MB recommended)
- Image dimension limits (< 8000x8000)

---

## Deployment Options

### Development
```bash
docker compose up -d          # Backend + database
cd frontend && npm run dev    # React frontend
cd flutter_app && flutter run # Flutter app
```

### Production (Backend)
```bash
docker compose -f docker-compose.prod.yml up -d
# Add nginx reverse proxy
# Add SSL certificates
# Add rate limiting
```

### Production (Flutter)
```bash
flutter build apk --release   # Android
flutter build ios --release   # iOS
flutter build linux --release # Linux desktop
```

---

## Monitoring and Observability

### Real-Time Metrics (Backend)
- CPU percentage
- Physical memory (VmRSS)
- Virtual memory (VmSize)
- Thread count
- Disk I/O (read/write)
- System load average
- Open file descriptors

### Logs
- Structured logging with timestamps
- Log levels: INFO, WARNING, ERROR
- Real-time streaming via SSE (React)
- Color-coded by type (system, OCR, error)

### Future: Metrics Export
- Prometheus exporter
- Grafana dashboards
- Alert manager integration

---

## References

- **PaddleOCR**: https://github.com/PaddlePaddle/PaddleOCR
- **Tesseract**: https://github.com/tesseract-ocr/tesseract
- **ML Kit**: https://developers.google.com/ml-kit/vision/text-recognition
- **Flutter**: https://flutter.dev
- **React**: https://react.dev

