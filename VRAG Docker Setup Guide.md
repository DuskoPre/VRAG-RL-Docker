# VRAG Docker Setup Guide

This guide provides a complete Docker containerization setup for the VRAG (Visual Retrieval-Augmented Generation) application from Alibaba-NLP.

## Prerequisites

- Docker with GPU support (Docker Desktop with NVIDIA Container Toolkit)
- NVIDIA GPU with CUDA support (recommended: A100 80G or similar)
- At least 32GB RAM
- 50GB+ free disk space

## Quick Start

### 1. Build the Docker Image

```bash
# Clone the repository and navigate to it
git clone https://github.com/Alibaba-NLP/VRAG.git
cd VRAG

# Copy the Dockerfile to the repository root
# (Copy the Dockerfile content from the previous artifact)

# Build the Docker image
docker build -t vrag-app .
```

### 2. Run the Container (Single Container Mode)

```bash
# Run the container with GPU support
docker run -it --gpus all \
    -p 8001:8001 \
    -p 8002:8002 \
    -p 8501:8501 \
    -v $(pwd)/search_engine/corpus:/app/search_engine/corpus \
    -v $(pwd)/models:/app/models \
    vrag-app
```

### 3. Access the Application

- **Streamlit Demo**: http://localhost:8501
- **VLM API**: http://localhost:8001
- **Search Engine API**: http://localhost:8002

## Multi-Service Setup with Docker Compose

### 1. Use Docker Compose (Recommended)

```bash
# Use the docker-compose.yml from the Docker image
docker-compose up -d
```

### 2. Check Service Status

```bash
# Check all services
docker-compose ps

# Check logs
docker-compose logs -f vrag-demo
```

## Setting Up Your Own Corpus

### 1. Prepare Your Documents

```bash
# Create the corpus directory
mkdir -p search_engine/corpus/img
mkdir -p search_engine/corpus/pdf

# Place your PDF documents in search_engine/corpus/pdf/
# Or place your JPG images directly in search_engine/corpus/img/
```

### 2. Run Corpus Setup

```bash
# Enter the container
docker exec -it vrag-app bash

# Run the corpus setup script
./setup_corpus.sh
```

### 3. Manual Corpus Setup (if needed)

```bash
# Convert PDFs to images (if you have PDFs)
python search_engine/corpus/pdf2images.py

# Test the embedding model
python ./search_engine/vl_embedding.py

# Run document ingestion
python ./search_engine/ingestion.py
```

## Service Configuration

### Environment Variables

You can customize the behavior using environment variables:

```bash
# Docker run with custom environment
docker run -it --gpus all \
    -p 8001:8001 -p 8002:8002 -p 8501:8501 \
    -e SEARCH_URL=http://localhost:8002/search \
    -e VLM_URL=http://localhost:8001/v1 \
    -e CUDA_VISIBLE_DEVICES=0 \
    -v $(pwd)/search_engine/corpus:/app/search_engine/corpus \
    vrag-app
```

### Model Configuration

The setup uses these models by default:
- **VLM Model**: `autumncc/Qwen2.5-VL-7B-VRAG`
- **Embedding Model**: `vidore/colqwen2-v1.0`

To use different models, modify the startup scripts or environment variables.

## API Usage

### Python API Example

```python
from vrag_agent import VRAG

# Initialize VRAG agent
vrag = VRAG(
    base_url='http://localhost:8001/v1',
    search_url='http://localhost:8002/search',
    generator=False
)

# Ask a question
answer = vrag.run('What is the capital of France?')
print(answer)
```

### REST API Example

```bash
# Search API
curl -X POST "http://localhost:8002/search" \
    -H "Content-Type: application/json" \
    -d '{"query": "your search query"}'

# VLM API (OpenAI-compatible)
curl -X POST "http://localhost:8001/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen2.5-VL-7B-Instruct",
        "messages": [{"role": "user", "content": "Hello"}]
    }'
```

## Resource Requirements

### Minimum Requirements
- **GPU**: 1x NVIDIA GPU with 16GB+ VRAM
- **RAM**: 32GB system RAM
- **Storage**: 50GB free space

### Recommended Requirements
- **GPU**: 1x NVIDIA A100 80G or similar
- **RAM**: 64GB+ system RAM
- **Storage**: 100GB+ SSD

## Troubleshooting

### Common Issues

1. **GPU Not Detected**
   ```bash
   # Check GPU support
   docker run --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi
   ```

2. **Out of Memory**
   ```bash
   # Reduce batch size or use smaller model
   # Modify the vllm serve command in start_services.sh
   ```

3. **Service Not Starting**
   ```bash
   # Check service logs
   docker-compose logs vrag-search
   docker-compose logs vrag-vlm
   docker-compose logs vrag-demo
   ```

4. **Model Download Issues**
   ```bash
   # Pre-download models
   python -c "from transformers import AutoModel; AutoModel.from_pretrained('autumncc/Qwen2.5-VL-7B-VRAG')"
   ```

### Performance Optimization

1. **Enable GPU Memory Optimization**
   ```bash
   # Add to vllm serve command
   --gpu-memory-utilization 0.8 --max-num-seqs 16
   ```

2. **Use Quantization**
   ```bash
   # Add quantization to reduce memory usage
   --quantization awq
   ```

## Development Setup

### For Development

```bash
# Mount source code for development
docker run -it --gpus all \
    -p 8001:8001 -p 8002:8002 -p 8501:8501 \
    -v $(pwd):/app \
    -v $(pwd)/search_engine/corpus:/app/search_engine/corpus \
    vrag-app bash

# Install additional development dependencies
pip install jupyter notebook ipython
```

### Building Custom Images

```bash
# Build with custom base image
docker build --build-arg BASE_IMAGE=nvidia/cuda:12.1-devel-ubuntu22.04 -t vrag-custom .

# Build with specific Python version
docker build --build-arg PYTHON_VERSION=3.10 -t vrag-py310 .
```

## Security Considerations

1. **Network Security**: The container exposes multiple ports. Use proper firewall rules in production.
2. **Model Security**: Models are downloaded from public repositories. Verify checksums if needed.
3. **Data Security**: Your corpus data is mounted as volumes. Ensure proper permissions.

## License and Attribution

This Docker setup is based on the VRAG project by Alibaba-NLP. Please refer to the original repository for licensing information and proper attribution.

## Support

For issues related to:
- **Docker setup**: Check this guide and Docker documentation
- **VRAG application**: Visit the [original repository](https://github.com/Alibaba-NLP/VRAG)
- **Model issues**: Check the respective model repositories on Hugging Face
