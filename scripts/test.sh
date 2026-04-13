#!/bin/bash

#export CUDA_VISIBLE_DIVICES=0
#export HF_ENDPOINT=https://hf-mirror.com
#export HF_DATASETS_OFFLINE=1
model_path="/remote_dir/home/maoweijiang/models/Qwen3.5-4B"

lm_eval --model hf \
    --model_args pretrained=$model_path \
    --batch_size 8 \
    --tasks zh-fineval \
    --include_path ./tasks/chinese \
    --device cuda:0 \
    --output_path results3 \
    --log_samples

#    --apply_chat_template
#    --hf_hub_log_args "hub_results_org=TheFinAI,results_repo_name=lm-eval-results,push_results_to_hub=True,push_samples_to_hub=True,public_repo=False" \