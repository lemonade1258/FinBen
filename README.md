# FinBen 评测环境：从零部署与避坑指南

本文档记录了在**离线高性能计算集群**（无外网、全局 `/data` 目录权限受限）中基于个人 Fork 的 FinBen 仓库，完整配置 `lm_eval` 评测框架的部署流程。

## 核心避坑总结 (TL;DR)

1. **Fork 仓库结构不完整**：`finlm_eval` 子模块经常缺失，需要手动删除并重新拉取。
2. **Hugging Face 网络与权限问题**：必须配置国内镜像并将所有缓存指向个人目录。
3. **YAML 配置文件硬编码**：旧任务配置中极大概率残留他人绝对路径，必须手动修改。

---

## 部署步骤

### Step 1: 仓库获取与结构修复

```bash
git clone https://github.com/lemonade1258/FinBen.git
cd FinBen

# 修复不完整的评测引擎
rm -rf finlm_eval
git clone https://github.com/The-FinAI/finlm_eval.git
```

### Step 2: Conda 环境配置

```bash
conda create -n finben python=3.12 -y
conda activate finben

cd finlm_eval
pip install -e .
pip install -e .[vllm]
cd ..

pip install -r requirements.txt
```

### Step 3: 清理 YAML 配置文件硬编码路径

打开 `tasks/chinese/` 目录下的 `.yaml` 文件（如 `zh-fineval.yaml`），修改 `dataset_kwargs` 部分：

```yaml
# 改前（他人路径，直接报错）
dataset_kwargs:
  cache_dir: /remote_dir/home/maoweijiang/.cache/huggingface/datasets/

# 改后（你自己的个人目录）
dataset_kwargs:
  cache_dir: /remote_dir/home/你的用户名/.cache/huggingface/datasets/
  trust_remote_code: true
```

> **注意**：必须将路径改为你自己的个人目录，严禁使用 `/data/` 开头的全局路径。

### Step 4: 编写并提交 Slurm 调度脚本

在 FinBen 根目录创建 `test.slurm` 文件：

```bash
#SBATCH --job-name=finben_eval
#SBATCH --partition=gre              # 修改为你的实际分区
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# 加载模块
module load conda/3
module load cuda/12.4

# 激活环境
eval "$(/persist_data/home/你的用户名/miniconda3/bin/conda shell.bash hook)"
conda activate finben

# 配置 Hugging Face 环境变量
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME="/remote_dir/home/你的用户名/.cache/huggingface"
export HF_DATASETS_CACHE="/remote_dir/home/你的用户名/.cache/huggingface/datasets"

# 进入项目根目录
cd "/remote_dir/home/你的用户名/finlm_eval/finben/FinBen"

# 执行评测（请根据实际情况修改 model_path）
model_path="/persist_data/home/你的用户名/model/Qwen2.5-0.5B"

lm_eval --model hf \
    --model_args pretrained=$model_path,trust_remote_code=True \
    --batch_size 8 \
    --tasks zh-fineval \
    --include_path ./tasks/chinese \
    --device cuda:0 \
    --output_path results \
    --log_samples \
    --verbosity DEBUG
```

提交任务前，先创建日志目录：

```bash
mkdir -p logs
sbatch test.slurm
```

---

## 重要提醒

- 所有缓存路径（`HF_HOME`、`HF_DATASETS_CACHE`、`cache_dir`）必须指向**个人目录**，否则会因权限问题失败。
- `requirements_finben.txt` 是保证环境一致性的关键文件，建议提交到仓库。
- 如遇路径相关报错，优先检查 YAML 文件中的 `cache_dir` 设置。

欢迎提交 Issue 或 Pull Request 共同完善集群部署方案。
