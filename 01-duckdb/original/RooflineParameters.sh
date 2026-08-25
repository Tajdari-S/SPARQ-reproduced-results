#!/bin/bash

# System Peak GFLOPs Calculator for Linux
# This script uses standard Linux tools to calculate theoretical peak performance

echo "=== System Peak GFLOPs Calculator ==="
echo

# Function to extract CPU information
get_cpu_info() {
    echo "=== CPU Information ==="
    
    # Get CPU details
    CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name: *//')
    CPU_CORES=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    CPU_THREADS=$(lscpu | grep "Thread(s) per core" | awk '{print $4}')
    CPU_SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')
    CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
    
    # Get frequency information
    BASE_FREQ=$(lscpu | grep "CPU MHz" | awk '{print $3}')
    MAX_FREQ=$(lscpu | grep "CPU max MHz" | awk '{print $4}')
    
    # Get SIMD capabilities
    SIMD_FLAGS=$(lscpu | grep "Flags" | grep -o -E "(sse|avx|avx2|avx512)" | sort -u | tr '\n' ' ')
    
    echo "Model: $CPU_MODEL"
    echo "Sockets: $CPU_SOCKETS"
    echo "Cores per socket: $CORES_PER_SOCKET"
    echo "Total cores: $CPU_CORES"
    echo "Threads per core: $CPU_THREADS"
    echo "Base frequency: $BASE_FREQ MHz"
    echo "Max frequency: $MAX_FREQ MHz"
    echo "SIMD support: $SIMD_FLAGS"
    echo
}

# Function to calculate CPU GFLOPs
calculate_cpu_gflops() {
    echo "=== CPU GFLOPs Calculation ==="
    
    # Use max frequency if available, otherwise base frequency
    if [ -n "$MAX_FREQ" ] && [ "$MAX_FREQ" != "" ]; then
        FREQ_GHZ=$(echo "scale=3; $MAX_FREQ / 1000" | bc)
        echo "Using max frequency: $FREQ_GHZ GHz"
    else
        FREQ_GHZ=$(echo "scale=3; $BASE_FREQ / 1000" | bc)
        echo "Using base frequency: $FREQ_GHZ GHz"
    fi
    
    # Determine SIMD width based on capabilities
    if echo "$SIMD_FLAGS" | grep -q "avx512"; then
        SIMD_WIDTH=16
        SIMD_TYPE="AVX-512"
    elif echo "$SIMD_FLAGS" | grep -q "avx2"; then
        SIMD_WIDTH=8
        SIMD_TYPE="AVX2"
    elif echo "$SIMD_FLAGS" | grep -q "avx"; then
        SIMD_WIDTH=8
        SIMD_TYPE="AVX"
    elif echo "$SIMD_FLAGS" | grep -q "sse"; then
        SIMD_WIDTH=4
        SIMD_TYPE="SSE"
    else
        SIMD_WIDTH=1
        SIMD_TYPE="Scalar"
    fi
    
    echo "SIMD capability: $SIMD_TYPE (width: $SIMD_WIDTH)"
    
    # Calculate GFLOPs (assuming FMA - Fused Multiply-Add = 2 ops per instruction)
    # Single precision
    SP_GFLOPS=$(echo "scale=2; $CPU_CORES * $FREQ_GHZ * $SIMD_WIDTH * 2" | bc)
    # Double precision (half the width for same register size)
    DP_SIMD=$(echo "scale=0; $SIMD_WIDTH / 2" | bc)
    DP_GFLOPS=$(echo "scale=2; $CPU_CORES * $FREQ_GHZ * $DP_SIMD * 2" | bc)
    
    echo "Peak Single Precision: $SP_GFLOPS GFLOPs"
    echo "Peak Double Precision: $DP_GFLOPS GFLOPs"
    echo
}

# Function to get GPU information
get_gpu_info() {
    echo "=== GPU Information ==="
    
    # Check for NVIDIA GPUs
    if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA GPUs detected:"
        nvidia-smi --query-gpu=name,memory.total,clocks.max.graphics --format=csv,noheader,nounits | while read line; do
            GPU_NAME=$(echo $line | cut -d',' -f1)
            GPU_MEMORY=$(echo $line | cut -d',' -f2)
            GPU_FREQ=$(echo $line | cut -d',' -f3)
            echo "  GPU: $GPU_NAME"
            echo "  Memory: ${GPU_MEMORY} MB"
            echo "  Max Graphics Clock: ${GPU_FREQ} MHz"
            
            # Estimate CUDA cores based on common architectures
            # This is approximate - actual specs vary
            if echo "$GPU_NAME" | grep -i "rtx 4090" &> /dev/null; then
                CUDA_CORES=16384
            elif echo "$GPU_NAME" | grep -i "rtx 4080" &> /dev/null; then
                CUDA_CORES=9728
            elif echo "$GPU_NAME" | grep -i "rtx 3090" &> /dev/null; then
                CUDA_CORES=10496
            elif echo "$GPU_NAME" | grep -i "a100" &> /dev/null; then
                CUDA_CORES=6912
            else
                echo "  Note: CUDA core count estimation not available for this GPU"
                CUDA_CORES=0
            fi
            
            if [ $CUDA_CORES -gt 0 ]; then
                GPU_FREQ_GHZ=$(echo "scale=3; $GPU_FREQ / 1000" | bc)
                GPU_SP_GFLOPS=$(echo "scale=0; $CUDA_CORES * $GPU_FREQ_GHZ * 1" | bc)
                echo "  Estimated CUDA Cores: $CUDA_CORES"
                echo "  Estimated Peak SP: $GPU_SP_GFLOPS GFLOPs"
            fi
            echo
        done
    fi
    
    # Check for AMD GPUs
    if command -v rocm-smi &> /dev/null; then
        echo "AMD GPUs detected:"
        rocm-smi --showproductname --showmeminfo vram --showclocks
        echo
    fi
    
    # Check for Intel GPUs
    if [ -d "/sys/class/drm" ]; then
        INTEL_GPUS=$(ls /sys/class/drm/ | grep "^card[0-9]$" | xargs -I {} sh -c 'if [ -f /sys/class/drm/{}/device/vendor ] && [ "$(cat /sys/class/drm/{}/device/vendor)" = "0x8086" ]; then echo {}; fi')
        if [ -n "$INTEL_GPUS" ]; then
            echo "Intel GPUs detected:"
            for gpu in $INTEL_GPUS; do
                if [ -f "/sys/class/drm/$gpu/device/device" ]; then
                    DEVICE_ID=$(cat /sys/class/drm/$gpu/device/device)
                    echo "  Device ID: $DEVICE_ID"
                fi
            done
            echo
        fi
    fi
}

# Function to get memory bandwidth
get_memory_info() {
    echo "=== Memory Information ==="
    
    # Get memory details from dmidecode (requires root)
    if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
        echo "Memory modules:"
        dmidecode -t memory | grep -E "(Size|Speed|Type:|Manufacturer)" | grep -v "No Module"
        
        # Calculate theoretical bandwidth
        MEMORY_SPEED=$(dmidecode -t memory | grep "Configured Memory Speed" | head -1 | awk '{print $4}')
        MEMORY_CHANNELS=$(dmidecode -t memory | grep "Size:" | grep -v "No Module" | wc -l)
        
        if [ -n "$MEMORY_SPEED" ] && [ $MEMORY_SPEED -gt 0 ]; then
            # Approximate bandwidth calculation (DDR = Double Data Rate)
            BANDWIDTH_GBPS=$(echo "scale=2; $MEMORY_SPEED * $MEMORY_CHANNELS * 8 / 1000" | bc)
            echo "Estimated memory bandwidth: $BANDWIDTH_GBPS GB/s"
            
            # Memory bandwidth limited GFLOPs
            SP_BW_GFLOPS=$(echo "scale=2; $BANDWIDTH_GBPS * 1000 / 4" | bc)  # 4 bytes per SP float
            DP_BW_GFLOPS=$(echo "scale=2; $BANDWIDTH_GBPS * 1000 / 8" | bc)  # 8 bytes per DP float
            echo "Memory bandwidth limited SP GFLOPs: $SP_BW_GFLOPS"
            echo "Memory bandwidth limited DP GFLOPs: $DP_BW_GFLOPS"
        fi
    else
        echo "Note: Run as root with dmidecode installed for detailed memory info"
        
        # Alternative: use /proc/meminfo for basic info
        TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_MEM_GB=$(echo "scale=2; $TOTAL_MEM / 1024 / 1024" | bc)
        echo "Total memory: $TOTAL_MEM_GB GB"
    fi
    echo
}

# Function to run benchmarks
run_benchmarks() {
    echo "=== Benchmark Options ==="
    echo "To measure actual performance, consider running:"
    echo
    echo "CPU Benchmarks:"
    echo "  - LINPACK: Download from Intel MKL or use OpenBLAS"
    echo "  - sysbench: sudo apt install sysbench && sysbench cpu run"
    echo "  - stress-ng: sudo apt install stress-ng && stress-ng --cpu \$CPU_CORES --timeout 60s --metrics"
    echo
    echo "Memory Benchmarks:"
    echo "  - STREAM: Download and compile STREAM benchmark"
    echo "  - mbw: sudo apt install mbw && mbw 256"
    echo
    echo "GPU Benchmarks:"
    echo "  - nvidia-smi: nvidia-smi dmon (for monitoring during workload)"
    echo "  - CUDA samples: deviceQuery, bandwidthTest"
    echo
}

# Function to create a simple CPU benchmark
simple_cpu_benchmark() {
    echo "=== Simple CPU Benchmark ==="
    echo "Running basic floating-point operations test..."
    
    # Create a simple benchmark script
    cat > /tmp/cpu_bench.c << 'EOF'
#include <stdio.h>
#include <time.h>
#include <omp.h>

int main() {
    const long long iterations = 1000000000LL;
    double result = 0.0;
    double a = 1.00001, b = 1.00002;
    
    clock_t start = clock();
    double start_time = omp_get_wtime();
    
    #pragma omp parallel for reduction(+:result)
    for (long long i = 0; i < iterations; i++) {
        result += a * b + (double)i;  // FMA operation
    }
    
    double end_time = omp_get_wtime();
    double elapsed = end_time - start_time;
    
    double gflops = (2.0 * iterations) / (elapsed * 1e9);  // 2 ops per iteration
    
    printf("Result: %f\n", result);
    printf("Time: %.3f seconds\n", elapsed);
    printf("Estimated GFLOPs: %.2f\n", gflops);
    
    return 0;
}
EOF

    # Try to compile and run if gcc and OpenMP are available
    if command -v gcc &> /dev/null; then
        if gcc -fopenmp -O3 -o /tmp/cpu_bench /tmp/cpu_bench.c 2>/dev/null; then
            echo "Running benchmark..."
            /tmp/cpu_bench
            rm -f /tmp/cpu_bench /tmp/cpu_bench.c
        else
            echo "Could not compile benchmark (missing gcc or OpenMP)"
            rm -f /tmp/cpu_bench.c
        fi
    else
        echo "gcc not available for benchmark compilation"
        rm -f /tmp/cpu_bench.c
    fi
    echo
}

# Main execution
main() {
    # Check for required tools
    if ! command -v bc &> /dev/null; then
        echo "Error: 'bc' calculator not found. Install with: sudo apt install bc"
        exit 1
    fi
    
    get_cpu_info
    calculate_cpu_gflops
    get_gpu_info
    get_memory_info
    run_benchmarks
    
    # Ask if user wants to run simple benchmark
    read -p "Run simple CPU benchmark? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        simple_cpu_benchmark
    fi
    
    echo "=== Summary ==="
    echo "Peak GFLOPs calculation complete."
    echo "Note: Theoretical peak performance is rarely achieved in practice."
    echo "Actual performance depends on memory bandwidth, algorithm efficiency,"
    echo "and workload characteristics."
}

# Run the main function
main "$@"
