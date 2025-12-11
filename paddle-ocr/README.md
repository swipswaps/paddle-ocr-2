# PaddleOCR Web App

A production-ready OCR web application with hybrid multi-engine processing, automatic rotation detection, and real-time system monitoring.

## Why This Tool Was Created

This project evolved from [receipts-ocr](https://github.com/swipswaps/receipts-ocr) to address several critical requirements:

### 1. **Multi-Engine OCR Cascade**
- **Fast engines first**: Tesseract (5-8s) → PaddleOCR (60-90s)
- **Early exit on success**: Don't wait for slower engines if fast engine succeeds
- **Confidence-based fallback**: Automatically escalates to more accurate engines when needed

### 2. **Real System Monitoring**
- **No fake progress messages**: Displays actual CPU, memory, and I/O metrics during PaddleOCR's "silent" processing phase
- **Live backend logs**: Real-time streaming of OCR engine output
- **System logs panel**: Dedicated panel for debugging and monitoring

### 3. **Automatic Image Preprocessing**
- **HEIC conversion**: Automatic conversion of iPhone HEIC images to JPEG
- **Rotation detection**: Tesseract OSD (Orientation and Script Detection) automatically detects and corrects image rotation
- **Manual rotation**: Rotate left/right buttons for manual correction
- **EXIF handling**: Proper EXIF rotation during HEIC conversion

### 4. **Production Architecture**
- **Docker-based backend**: Isolated Python environment with PaddleOCR, Tesseract, and PostgreSQL
- **React frontend**: Modern TypeScript React app with Vite
- **Database persistence**: PostgreSQL for scan history and results
- **Health monitoring**: Automatic backend health checks with troubleshooting wizard

### 5. **Developer Experience**
- **Systematic code sync**: Built with [repo-puller](./repo-puller/) to ensure no code is lost or fabricated during development
- **Comprehensive logging**: systemLogger integration throughout the stack
- **Type safety**: Full TypeScript implementation

## Features

### OCR Processing
- ✅ **Hybrid OCR**: Tesseract → PaddleOCR cascade with confidence thresholds
- ✅ **HEIC Support**: Automatic conversion of iPhone images
- ✅ **Auto-rotation**: Tesseract OSD detects and corrects image orientation
- ✅ **Manual rotation**: Rotate images left/right by 90°
- ✅ **Drag & drop**: Upload images via drag-and-drop or file picker
- ✅ **Preview**: Image preview before OCR processing

### Monitoring & Debugging
- ✅ **System logs panel**: Real-time system and OCR logs
- ✅ **Backend health check**: Automatic health monitoring on mount
- ✅ **Troubleshooting wizard**: Step-by-step debugging for Docker/backend issues
- ✅ **Live backend logs**: Server-Sent Events (SSE) streaming

### Data Management
- ✅ **Scan history**: PostgreSQL database for all OCR results
- ✅ **Scan details modal**: View and manage previous scans
- ✅ **Export results**: Download OCR results as JSON or text
- ✅ **Clear history**: Bulk delete all scans

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     React Frontend (Vite)                   │
│  - TypeScript + React                                       │
│  - SystemLogsPanel, TroubleshootingWizard                  │
│  - heic2any for HEIC conversion                            │
│  - Lucide React icons                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/SSE
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Python Backend (Docker)                   │
│  - Flask + Gunicorn                                         │
│  - PaddleOCR PP-OCRv5 (95-99% accuracy, 60-90s)           │
│  - Tesseract 5 (85-90% accuracy, 5-8s)                    │
│  - PostgreSQL 15                                            │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 20+
- Python 3.9+ (for backend development)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/swipswaps/paddle-ocr-2.git
cd paddle-ocr-2
```

2. **Start the backend**
```bash
docker compose up -d
```

3. **Install frontend dependencies**
```bash
npm install
```

4. **Start the frontend**
```bash
npm run dev
```

5. **Open the app**
```
http://localhost:3000
```

### Docker Services

- **paddleocr-backend**: Python Flask backend on port 5001
- **postgres**: PostgreSQL database on port 5432
- **paddleocr-frontend**: Vite dev server on port 3000

## Usage

### Basic OCR Workflow

1. **Upload an image**
   - Click "Select Image" or drag & drop
   - Supports: JPG, PNG, HEIC, WebP

2. **Automatic preprocessing**
   - HEIC → JPEG conversion (if needed)
   - Rotation detection via Tesseract OSD
   - Image preview displayed

3. **Extract text**
   - Click "Extract Text" button
   - Hybrid OCR: Tesseract → PaddleOCR
   - Real-time logs in System Logs panel

4. **View results**
   - Text output or JSON format
   - Save to database
   - Export as file

### Manual Rotation

If automatic rotation detection fails:
- Use ⟲ (Rotate Left) or ⟳ (Rotate Right) buttons
- Each click rotates 90°

### Troubleshooting

If backend is unavailable:
1. Click "Troubleshoot" button
2. Follow step-by-step wizard
3. Check Docker status, logs, and connectivity

## API Endpoints

- `POST /ocr/hybrid` - Multi-engine OCR cascade
- `POST /detect-rotation` - Tesseract OSD rotation detection
- `GET /health` - Backend health check
- `GET /logs/stream` - Server-Sent Events log streaming
- `GET /scans` - List all scans
- `POST /scans` - Save scan result
- `DELETE /scans/:id` - Delete scan
- `DELETE /scans` - Clear all scans

## Development

### Repo Puller Tool

This project includes a custom `repo-puller` tool to systematically sync code from reference repositories without mistakes:

```bash
cd repo-puller
python3 sync.py --source ~/Documents/receipts-ocr --target ~/Documents/paddle-ocr --dry-run
```

See [repo-puller/README.md](./repo-puller/README.md) for details.

## License

MIT

## Credits

- Based on [receipts-ocr](https://github.com/swipswaps/receipts-ocr)
- PaddleOCR by PaddlePaddle
- Tesseract OCR by Google

