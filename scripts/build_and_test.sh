#!/bin/bash
# Build and Test Hybrid OCR Backend
#
# Usage:
#   ./scripts/build_and_test.sh

set -e  # Exit on error

echo "========================================="
echo "🚀 Building Hybrid OCR Backend"
echo "========================================="

# Navigate to project root
cd "$(dirname "$0")/.."

# Build Docker image
echo ""
echo "📦 Building Docker image..."
docker compose build paddleocr-backend

echo ""
echo "✅ Build complete!"
echo ""
echo "========================================="
echo "🧪 Testing Backend"
echo "========================================="

# Start services
echo ""
echo "🔄 Starting services..."
docker compose up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check health
echo ""
echo "🏥 Checking health..."
curl -f http://localhost:5001/health || echo "❌ Health check failed"

echo ""
echo "========================================="
echo "📊 Service Status"
echo "========================================="
docker compose ps

echo ""
echo "========================================="
echo "🎯 Test Endpoints"
echo "========================================="

echo ""
echo "Available endpoints:"
echo "  POST http://localhost:5001/ocr/hybrid - Hybrid OCR (recommended)"
echo "  POST http://localhost:5001/ocr/parse - Parse receipt text"
echo "  POST http://localhost:5001/ocr - Legacy PaddleOCR only"
echo ""
echo "Example usage:"
echo "  curl -X POST http://localhost:5001/ocr/hybrid -F 'file=@receipt.jpg'"
echo "  curl -X POST http://localhost:5001/ocr/parse -H 'Content-Type: application/json' -d '{\"text\": \"Store\\n12/09/2025\\nTotal: \$45.67\"}'"
echo ""
echo "View logs:"
echo "  docker compose logs -f backend"
echo ""
echo "Stop services:"
echo "  docker compose down"
echo ""
echo "✅ Setup complete!"

