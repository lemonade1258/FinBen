### 第一步：请你现在终端里执行导出（保存当前状态）

请在你当前已经跑通的登录节点上，激活环境并导出依赖项。推荐使用 `conda env export` 或者 `pip freeze`，这里提供最常用的 `pip` 导出方式：

Bash

```
# 1. 确保激活了你当前能跑通的环境
conda activate finben

# 2. 将环境依赖导出为 requirements.txt 文件
pip freeze > requirements_finben.txt
```

*(执行完后，你可以把这个 `requirements_finben.txt` 文件连同代码一起提交到你们的 Git 仓库里。)*

------

### 第二步：全新的 Markdown 部署文档

这版文档修复了格式显示问题，移除了误导的降级步骤，并全面接入了你刚刚导出的环境配置文件。你可以直接复制以下内容作为你们的 `README_SETUP.md`：

Markdown

```
# FinBen 评测环境：从零部署与避坑指南

本文档记录了基于个人 Fork 版本的 FinBen 仓库，在集群环境中从头配置 `lm_eval` 评测框架的完整通关流程。针对集群离线/无外网环境、权限限制以及旧代码遗留问题提供了标准解决方案。

## 核心避坑总结 (TL;DR)
1. **Fork 仓库不完整**：Fork 的代码可能缺失 `finlm_eval` 子模块，需要手动删除旧文件夹并重新拉取官方版本。
2. **Hugging Face 网络与权限**：必须配置国内镜像（`HF_ENDPOINT`）并将缓存路径（`HF_HOME`）指向个人目录，避开系统的 `/data` 全局权限限制。
3. **警惕 YAML 配置文件“下毒”**：旧的自定义 task 配置文件中极大概率写死了前人的绝对路径（如 `/data/xxx/...`），必须手动修改为当前用户的合法缓存路径。

---

## 🚀 Step 1: 仓库获取与结构修复

由于个人 Fork 的 `FinBen` 仓库中可能存在不完整的 `finlm_eval` 结构，我们需要手动修复：

```bash
# 1. 克隆你自己的 Fork 仓库
git clone [https://github.com/lemonade1258/FinBen.git](https://github.com/lemonade1258/FinBen.git)
cd FinBen

# 2. 删除损坏或不完整的评测子模块
rm -rf finlm_eval

# 3. 重新拉取官方的最新评测引擎作为子目录
git clone [https://github.com/The-FinAI/finlm_eval.git](https://github.com/The-FinAI/finlm_eval.git)
```

## 📦 Step 2: Conda 环境配置与依赖恢复

直接使用已验证健康的 `requirements_finben.txt` 恢复环境，避免任何版本冲突。

Bash

```
# 1. 创建并激活全新环境
conda create -n finben python=3.12 -y
conda activate finben

# 2. 进入评测引擎目录进行基础安装
cd finlm_eval
pip install -e .
pip install -e .[vllm]

# 3. 退回到上级目录，基于导出文件严格对齐所有依赖版本
cd ..
pip install -r requirements_finben.txt
```

## 🛠️ Step 3: 清理 YAML 配置文件中的硬编码路径

如果你使用了自定义的评测任务（如 `zh-fineval`），请务必检查 `FinBen/tasks/chinese/` 目录下的 `.yaml` 配置文件。

**排查与修改：**

打开对应的配置文件（例如 `zh-fineval.yaml`），检查 `dataset_kwargs` 字段。

- **错误示例（写死了别人的绝对路径）：**

  YAML

  ```
  dataset_kwargs:
    cache_dir: /data/wangyuxin/.cache/huggingface/datasets/
  ```

- **正确修改（改为你自己的合法路径）：**

  YAML

  ```
  dataset_kwargs:
    cache_dir: /remote_dir/home/maoweijiang/.cache/huggingface/datasets/
    trust_remote_code: true
  ```

*(注：只需修改路径，其他参数保持原样即可。)*

## 📝 Step 4: 编写并提交 Slurm 调度脚本

最后，回到 `FinBen` 根目录。在提交任务时，必须注入 Hugging Face 的环境变量来解决网络下载和缓存位置无权限的问题。

创建 `test.slurm` 文件，填入以下标准模板：

Bash

```
#!/bin/bash
#SBATCH --job-name=finben_eval
#SBATCH --partition=gre              # 保持与您的集群分区一致
#SBATCH --gres=gpu:1                 # 申请1张GPU
#SBATCH --cpus-per-task=16           # 申请16个CPU核心
#SBATCH --mem=128G                   # 申请128G内存
#SBATCH --time=48:00:00              # 限制运行时间
#SBATCH --output=logs/%x-%j.out      # 标准输出日志路径 (需提前创建 logs 文件夹)
#SBATCH --error=logs/%x-%j.err       # 错误日志路径

set -euo pipefail

# 1) 加载模块
module load conda/3
module load cuda/12.4

# 2) 激活环境
eval "$(/persist_data/home/maoweijiang/miniconda3/bin/conda shell.bash hook)"
conda activate finben

# 3) 配置核心环境变量（解决网络与权限报错）
# 启用国内镜像源
export HF_ENDPOINT=[https://hf-mirror.com](https://hf-mirror.com)
# 强制将缓存目录指向个人目录，绕过 /data 权限不足的问题
export HF_HOME="/remote_dir/home/maoweijiang/.cache/huggingface"
export HF_DATASETS_CACHE="/remote_dir/home/maoweijiang/.cache/huggingface/datasets"

# 4) 进入项目根目录 (必须在此目录下执行以匹配相对路径)
cd "/remote_dir/home/maoweijiang/finlm_eval/finben/FinBen"

# 5) 执行评估脚本
model_path="/persist_data/home/maoweijiang/model/Qwen2.5-0.5B"

lm_eval --model hf \
    --model_args pretrained=$model_path,trust_remote_code=True \
    --batch_size 8 \
    --tasks zh-fineval \
    --include_path ./tasks/chinese \
    --device cuda:0 \
    --output_path results3 \
    --log_samples \
    --verbosity DEBUG
```

**运行任务：**

Bash

```
# 首次运行前务必创建日志文件夹，否则 Slurm 会直接报错
mkdir -p logs
sbatch test.slurm
```