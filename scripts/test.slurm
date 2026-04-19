#!/bin/bash
#SBATCH --job-name=finben_eval
#SBATCH --partition=gre              
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# 1) 加载模块
module load conda/3
module load cuda/12.4

# 2) 激活环境
eval "$(/persist_data/home/maoweijiang/miniconda3/bin/conda shell.bash hook)"
conda activate finben

# 3) 配置核心环境变量
# 启用国内镜像源解决网络下载问题
export HF_ENDPOINT=https://hf-mirror.com
# 【新增】强制将缓存目录指向你的个人目录，解决 /data 权限不足的问题
export HF_HOME="/remote_dir/home/maoweijiang/.cache/huggingface"
export HF_DATASETS_CACHE="/remote_dir/home/maoweijiang/.cache/huggingface/datasets"

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:$LD_LIBRARY_PATH"

# 4) 进入项目根目录
cd "/remote_dir/home/maoweijiang/finlm_eval/finben/FinBen"

# 5) 执行评估脚本
model_path="/persist_data/home/maoweijiang/model/Qwen2.5-0.5B"

lm_eval --model vllm \
    --model_args pretrained=$model_path,trust_remote_code=True,gpu_memory_utilization=0.6,max_model_len=4096,tensor_parallel_size=1 \
    --batch_size 16 \
    --tasks FINEVAL_test \
    --include_path ./tasks/demo \
    --output_path results \
    --log_samples \
    --verbosity DEBUG