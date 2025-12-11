#!/bin/bash
# Start PaddleOCR App with Docker Compose

echo "🚀 Starting PaddleOCR App..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi

# Build and start services
echo "📦 Building and starting services..."
docker compose up -d --build

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check service status
echo ""
echo "📊 Service Status:"
docker compose ps

echo ""
echo "✅ PaddleOCR App is starting!"
echo ""
echo "🌐 Frontend: http://localhost:5173"
echo "🔧 Backend:  http://localhost:5001"
echo ""
echo "📋 View logs with: docker compose logs -f"
echo "🛑 Stop with:      docker compose down"
echo ""
