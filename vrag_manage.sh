#!/bin/bash
# VRAG Docker Management Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="vrag"
COMPOSE_FILE="docker-compose.yml"
DOCKERFILE="Dockerfile"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check NVIDIA Docker support
    if ! docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        log_error "NVIDIA Docker support is not available. Please install NVIDIA Container Toolkit."
        exit 1
    fi
    
    # Check available GPU memory
    gpu_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    if [ "$gpu_memory" -lt 16384 ]; then
        log_warn "GPU memory is less than 16GB. VRAG may not work properly."
    fi
    
    log_info "All requirements satisfied."
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Create necessary directories
    mkdir -p search_engine/corpus/img
    mkdir -p search_engine/corpus/pdf
    mkdir -p models
    mkdir -p data
    
    # Create environment file if it doesn't exist
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# VRAG Environment Configuration
CUDA_VISIBLE_DEVICES=0
PYTHONPATH=/app

# Service URLs
SEARCH_URL=http://vrag-search:8002/search
VLM_URL=http://vrag-vlm:8001/v1

# Ports
SEARCH_PORT=8002
VLM_PORT=8001
STREAMLIT_PORT=8501

# Logging
LOG_LEVEL=INFO
EOF
        log_info "Created .env file with default configuration."
    fi
    
    log_info "Environment setup complete."
}

build_images() {
    log_info "Building Docker images..."
    docker-compose build
    log_info "Docker images built successfully."
}

start_services() {
    log_info "Starting VRAG services..."
    
    # Start core services
    docker-compose up -d vrag-search vrag-vlm
    
    # Wait for services to be healthy
    log_info "Waiting for search engine to be ready..."
    timeout=300
    counter=0
    while ! docker-compose exec vrag-search curl -f http://localhost:8002/health &> /dev/null; do
        if [ $counter -gt $timeout ]; then
            log_error "Search engine failed to start within timeout."
            exit 1
        fi
        sleep 5
        counter=$((counter + 5))
        echo -n "."
    done
    echo ""
    log_info "Search engine is ready."
    
    log_info "Waiting for VLM server to be ready..."
    counter=0
    while ! docker-compose exec vrag-vlm curl -f http://localhost:8001/health &> /dev/null; do
        if [ $counter -gt $timeout ]; then
            log_error "VLM server failed to start within timeout."
            exit 1
        fi
        sleep 10
        counter=$((counter + 10))
        echo -n "."
    done
    echo ""
    log_info "VLM server is ready."
    
    # Start demo service
    docker-compose up -d vrag-demo
    
    log_info "All services started successfully."
    log_info "Access the demo at: http://localhost:8501"
}

stop_services() {
    log_info "Stopping VRAG services..."
    docker-compose down
    log_info "Services stopped."
}

restart_services() {
    log_info "Restarting VRAG services..."
    docker-compose restart
    log_info "Services restarted."
}

show_status() {
    log_info "Service status:"
    docker-compose ps
    
    log_info "Service logs (last 20 lines):"
    docker-compose logs --tail=20
}

show_logs() {
    service=${1:-""}
    if [ -z "$service" ]; then
        docker-compose logs -f
    else
        docker-compose logs -f "$service"
    fi
}

setup_corpus() {
    log_info "Setting up corpus..."
    
    # Check if corpus directory has content
    if [ ! "$(ls -A search_engine/corpus/img)" ] && [ ! "$(ls -A search_engine/corpus/pdf)" ]; then
        log_warn "No corpus data found. Please add your documents to:"
        log_warn "  - PDF files: search_engine/corpus/pdf/"
        log_warn "  - Image files: search_engine/corpus/img/"
        exit 1
    fi
    
    # Run corpus setup
    docker-compose --profile setup run --rm vrag-setup
    log_info "Corpus setup complete."
}

cleanup() {
    log_info "Cleaning up Docker resources..."
    docker-compose down --volumes --remove-orphans
    docker system prune -f
    log_info "Cleanup complete."
}

backup_data() {
    backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup in $backup_dir..."
    
    mkdir -p "$backup_dir"
    cp -r search_engine/corpus "$backup_dir/"
    cp -r models "$backup_dir/"
    cp -r data "$backup_dir/"
    
    log_info "Backup created successfully."
}

restore_data() {
    backup_dir=$1
    if [ -z "$backup_dir" ]; then
        log_error "Please specify backup directory."
        exit 1
    fi
    
    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory does not exist."
        exit 1
    fi
    
    log_info "Restoring data from $backup_dir..."
    
    # Stop services first
    docker-compose down
    
    # Restore data
    cp -r "$backup_dir/corpus" search_engine/
    cp -r "$backup_dir/models" .
    cp -r "$backup_dir/data" .
    
    log_info "Data restored successfully."
}

update_models() {
    log_info "Updating models..."
    
    # Pull latest models
    docker-compose exec vrag-vlm python -c "
from transformers import AutoTokenizer, AutoModel
import torch

# Download/update VLM model
model_name = 'autumncc/Qwen2.5-VL-7B-VRAG'
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name, torch_dtype=torch.float16)

print('VLM model updated successfully')
"
    
    docker-compose exec vrag-search python -c "
from sentence_transformers import SentenceTransformer

# Download/update embedding model
model_name = 'vidore/colqwen2-v1.0'
model = SentenceTransformer(model_name)

print('Embedding model updated successfully')
"
    
    log_info "Models updated successfully."
}

install_dev_tools() {
    log_info "Installing development tools..."
    
    # Install additional development dependencies
    docker-compose exec vrag-demo pip install \
        jupyter \
        notebook \
        ipython \
        debugpy \
        pytest \
        black \
        flake8
    
    log_info "Development tools installed."
}

run_tests() {
    log_info "Running tests..."
    
    # Run basic health checks
    docker-compose exec vrag-search python -c "
import requests
import sys

try:
    response = requests.get('http://localhost:8002/health')
    if response.status_code == 200:
        print('✓ Search engine health check passed')
    else:
        print('✗ Search engine health check failed')
        sys.exit(1)
except Exception as e:
    print(f'✗ Search engine health check failed: {e}')
    sys.exit(1)
"
    
    docker-compose exec vrag-vlm python -c "
import requests
import sys

try:
    response = requests.get('http://localhost:8001/health')
    if response.status_code == 200:
        print('✓ VLM server health check passed')
    else:
        print('✗ VLM server health check failed')
        sys.exit(1)
except Exception as e:
    print(f'✗ VLM server health check failed: {e}')
    sys.exit(1)
"
    
    docker-compose exec vrag-demo python -c "
import requests
import sys

try:
    response = requests.get('http://localhost:8501/_stcore/health')
    if response.status_code == 200:
        print('✓ Streamlit demo health check passed')
    else:
        print('✗ Streamlit demo health check failed')
        sys.exit(1)
except Exception as e:
    print(f'✗ Streamlit demo health check failed: {e}')
    sys.exit(1)
"
    
    log_info "All tests passed."
}

show_help() {
    cat << EOF
VRAG Docker Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    check           Check system requirements
    setup           Setup environment and directories
    build           Build Docker images
    start           Start all services
    stop            Stop all services
    restart         Restart all services
    status          Show service status
    logs [SERVICE]  Show logs (optionally for specific service)
    corpus          Setup corpus data
    cleanup         Clean up Docker resources
    backup          Backup data
    restore DIR     Restore data from backup directory
    update-models   Update AI models
    dev-tools       Install development tools
    test            Run health checks
    help            Show this help message

Examples:
    $0 check                    # Check requirements
    $0 setup                    # Setup environment
    $0 build                    # Build images
    $0 start                    # Start services
    $0 logs vrag-demo          # Show demo logs
    $0 corpus                   # Setup corpus
    $0 backup                   # Create backup
    $0 restore backup_20240101  # Restore from backup

Services:
    vrag-search     Search engine API server
    vrag-vlm        VLM (Vision Language Model) server
    vrag-demo       Streamlit demo interface

Ports:
    8001            VLM API server
    8002            Search engine API
    8501            Streamlit demo

For more information, visit: https://github.com/Alibaba-NLP/VRAG
EOF
}

# Main script logic
case "$1" in
    check)
        check_requirements
        ;;
    setup)
        setup_environment
        ;;
    build)
        build_images
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    corpus)
        setup_corpus
        ;;
    cleanup)
        cleanup
        ;;
    backup)
        backup_data
        ;;
    restore)
        restore_data "$2"
        ;;
    update-models)
        update_models
        ;;
    dev-tools)
        install_dev_tools
        ;;
    test)
        run_tests
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        log_info "VRAG Docker Management Script"
        log_info "Run '$0 help' for usage information."
        ;;
    *)
        log_error "Unknown command: $1"
        log_info "Run '$0 help' for usage information."
        exit 1
        ;;
esac
