# VRAG-RL-Docker

Repo for "VRAG-RL: Empower Vision-Perception-Based RAG for Visually Rich Information Understanding via Iterative Reasoning with Reinforcement Learning" hosted with Docker

## 🐳 Complete Docker Setup for VRAG

### 1. Multi-stage Dockerfile
- CUDA 12.1 base image with GPU support
- Python 3.10 environment
- All necessary dependencies (PyTorch, Transformers, VLLM, Streamlit, etc.)
- Automated service startup scripts
- Health check endpoints

### 2. Docker Compose Configuration
**Three main services:**
- `vrag-search`: Search engine API (port 8002)
- `vrag-vlm`: Vision Language Model server (port 8001)
- `vrag-demo`: Streamlit demo interface (port 8501)

**Features:**
- GPU resource allocation
- Service dependencies and health checks
- Volume mounts for data persistence

### 3. Comprehensive Setup Guide
- Step-by-step installation instructions
- Requirements and troubleshooting
- API usage examples
- Performance optimization tips

### 4. Management Script
- Easy-to-use command-line interface
- Service management (start/stop/restart)
- Corpus setup automation
- Backup and restore functionality
- Health checks and monitoring

## 🚀 Quick Start

1. **Save the Dockerfile** in your VRAG repository root
2. **Save the docker-compose.yml** file
3. **Make the startup script executable:**
   ```bash
   chmod +x vrag_manage.sh
   ```
4. **Run the setup:**
   ```bash
   ./vrag_manage.sh check    # Check requirements
   ./vrag_manage.sh setup    # Setup environment
   ./vrag_manage.sh build    # Build images
   ./vrag_manage.sh start    # Start services
   ```

## 📊 Resource Requirements

- **Minimum:** 1x GPU (16GB VRAM), 32GB RAM
- **Recommended:** 1x A100 (80GB), 64GB RAM
- **Storage:** 50GB+ free space

## 🔧 Key Features

- **GPU Support:** Full NVIDIA CUDA integration
- **Multi-service Architecture:** Separate containers for each component
- **Health Monitoring:** Automated health checks
- **Data Persistence:** Volume mounts for models and corpus
- **Development Support:** Debug configurations and dev tools
- **Production Ready:** Resource limits and restart policies

## 🏗️ Architecture Overview

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Streamlit Demo    │    │    VLM Server       │    │   Search Engine     │
│   (Port 8501)      │◄──►│   (Port 8001)       │◄──►│   (Port 8002)       │
│                     │    │                     │    │                     │
│ - User Interface    │    │ - Qwen2.5-VL-7B     │    │ - ColPali Embeddings│
│ - Query Processing  │    │ - Vision Language    │    │ - Document Retrieval│
│ - Result Display    │    │ - Text Generation    │    │ - Vector Search     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## 📁 Project Structure

```
VRAG-RL-Docker/
├── Dockerfile
├── docker-compose.yml
├── vrag_manage.sh
├── README.md
├── search_engine/
│   ├── corpus/
│   │   ├── img/          # Document images
│   │   └── pdf/          # PDF documents
│   └── ...
├── models/               # AI models cache
├── data/                 # Application data
└── demo/
    └── app.py           # Streamlit application
```

## 🛠️ Installation Steps

### Prerequisites
- Docker with GPU support
- NVIDIA Container Toolkit
- CUDA-compatible GPU (16GB+ VRAM recommended)

### Step 1: Clone and Setup
```bash
git clone https://github.com/Alibaba-NLP/VRAG.git
cd VRAG

# Copy Docker files to repository
# (Copy Dockerfile, docker-compose.yml, and vrag_manage.sh)

chmod +x vrag_manage.sh
```

### Step 2: Environment Check
```bash
./vrag_manage.sh check
```

### Step 3: Build and Start
```bash
./vrag_manage.sh setup
./vrag_manage.sh build
./vrag_manage.sh start
```

### Step 4: Access Services
- **Demo Interface:** http://localhost:8501
- **VLM API:** http://localhost:8001
- **Search API:** http://localhost:8002

## 📖 Usage Examples

### Python API
```python
from vrag_agent import VRAG

# Initialize VRAG agent
vrag = VRAG(
    base_url='http://localhost:8001/v1',
    search_url='http://localhost:8002/search',
    generator=False
)

# Query the system
answer = vrag.run('What is shown in the financial report?')
print(answer)
```

### REST API
```bash
# Search documents
curl -X POST "http://localhost:8002/search" \
    -H "Content-Type: application/json" \
    -d '{"query": "financial performance"}'

# VLM inference
curl -X POST "http://localhost:8001/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "Qwen/Qwen2.5-VL-7B-Instruct",
        "messages": [{"role": "user", "content": "Analyze this image"}]
    }'
```

## 🗂️ Document Management

### Adding Your Own Corpus
1. **Place documents:**
   ```bash
   # PDF files
   cp your_documents.pdf search_engine/corpus/pdf/
   
   # Or image files directly
   cp your_images.jpg search_engine/corpus/img/
   ```

2. **Setup corpus:**
   ```bash
   ./vrag_manage.sh corpus
   ```

## 🔧 Management Commands

```bash
# Service management
./vrag_manage.sh start      # Start all services
./vrag_manage.sh stop       # Stop all services
./vrag_manage.sh restart    # Restart services
./vrag_manage.sh status     # Check service status

# Monitoring
./vrag_manage.sh logs       # View all logs
./vrag_manage.sh logs vrag-demo  # View specific service logs

# Maintenance
./vrag_manage.sh backup     # Create data backup
./vrag_manage.sh cleanup    # Clean up resources
./vrag_manage.sh test       # Run health checks
```

## 🐛 Troubleshooting

### Common Issues

1. **GPU Not Detected**
   ```bash
   # Test GPU support
   docker run --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi
   ```

2. **Out of Memory**
   ```bash
   # Check GPU memory usage
   nvidia-smi
   
   # Reduce memory usage in docker-compose.yml
   # Add: --gpu-memory-utilization 0.6
   ```

3. **Service Not Starting**
   ```bash
   # Check service logs
   ./vrag_manage.sh logs vrag-search
   ./vrag_manage.sh logs vrag-vlm
   ```

4. **Port Conflicts**
   ```bash
   # Check port usage
   netstat -tlnp | grep -E ':(8001|8002|8501)'
   
   # Modify ports in docker-compose.yml if needed
   ```

## 🚀 Performance Optimization

### GPU Memory Optimization
```yaml
# In docker-compose.yml, add to vrag-vlm service:
command: >
  vllm serve autumncc/Qwen2.5-VL-7B-VRAG 
  --gpu-memory-utilization 0.8
  --max-num-seqs 16
  --quantization awq
```

### CPU Optimization
```yaml
# Add resource limits
deploy:
  resources:
    limits:
      cpus: '8'
      memory: 32G
```

## 📊 Monitoring and Logging

### Health Checks
```bash
# Manual health checks
curl http://localhost:8001/health  # VLM server
curl http://localhost:8002/health  # Search engine
curl http://localhost:8501/_stcore/health  # Streamlit
```

### Log Management
```bash
# View logs with timestamps
docker-compose logs -f -t

# Filter logs by service
docker-compose logs -f vrag-demo

# Export logs
docker-compose logs > vrag_logs.txt
```

## 🔐 Security Considerations

- **Network Security:** Services expose multiple ports - use firewall rules in production
- **Model Security:** Models downloaded from public repositories - verify checksums
- **Data Security:** Corpus data mounted as volumes - ensure proper file permissions

## 📄 License

This Docker setup is based on the VRAG project by Alibaba-NLP. Please refer to the [original repository](https://github.com/Alibaba-NLP/VRAG) for licensing information.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./vrag_manage.sh test`
5. Submit a pull request

## 📞 Support

For issues related to:
- **Docker setup:** Check this README and Docker documentation
- **VRAG application:** Visit the [original repository](https://github.com/Alibaba-NLP/VRAG)
- **Model issues:** Check respective model repositories on Hugging Face

## 🔗 Related Projects

- [VRAG Original Repository](https://github.com/Alibaba-NLP/VRAG)
- [ViDoRAG](https://github.com/Alibaba-NLP/ViDoRAG)
- [LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory)

---

**Note:** The setup handles all the complexity of running VRAG with its multiple components (search engine, VLM server, and demo interface) in a containerized environment, making it easy to deploy and manage.
