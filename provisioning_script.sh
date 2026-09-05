#!/bin/bash
# ============================================================================
# provisioning_ace_step_xl.sh
# ใช้กับ Vast.AI ผ่าน environment variable "PROVISIONING_SCRIPT"
# โหลดโมเดล ACE-Step 1.5 XL (turbo) + text encoder + VAE + workflow + custom
# node ที่จำเป็น สำหรับสร้างเพลง Lofi/Piano ลง YouTube
# ไม่ต้องใช้ HF_TOKEN — repo นี้ไม่ gated
# ============================================================================

set -eo pipefail

# ----------------------------------------------------------------------------
# ส่วนที่ 0: หา path จริงของ ComfyUI บนเครื่องนี้
# ----------------------------------------------------------------------------
echo ">>> กำลังค้นหาโฟลเดอร์ ComfyUI บนเครื่องนี้..."
COMFY_DIR=$(find / -maxdepth 5 -iname "ComfyUI" -type d 2>/dev/null | head -n 1)

if [ -z "$COMFY_DIR" ]; then
  COMFY_DIR="/workspace/ComfyUI"
  echo ">>> ไม่เจอโฟลเดอร์ที่มีอยู่แล้ว จะใช้ path เริ่มต้น: $COMFY_DIR"
else
  echo ">>> เจอ ComfyUI ที่: $COMFY_DIR"
fi

MODELS_DIR="$COMFY_DIR/models"

mkdir -p "$MODELS_DIR/diffusion_models"
mkdir -p "$MODELS_DIR/text_encoders"
mkdir -p "$MODELS_DIR/vae"
mkdir -p "$COMFY_DIR/user/default/workflows"
mkdir -p "$COMFY_DIR/custom_nodes"

# ----------------------------------------------------------------------------
# ฟังก์ชันช่วยโหลดไฟล์ + ข้ามถ้ามีอยู่แล้ว (กันโหลดซ้ำถ้ารันสคริปต์ซ้ำ)
# ----------------------------------------------------------------------------
download_if_missing() {
  local url="$1"
  local dest="$2"

  if [ -f "$dest" ]; then
    echo ">>> ข้ามไป (มีไฟล์อยู่แล้ว): $dest"
    return
  fi

  echo ">>> กำลังโหลด: $(basename "$dest")"
  wget -q --show-progress -O "$dest" "$url"
  echo ">>> เสร็จแล้ว: $dest"
}

# ----------------------------------------------------------------------------
# ส่วนที่ 1: Diffusion Model — XL turbo (bf16)
# ----------------------------------------------------------------------------
# ใช้ turbo เพราะเร็วสุด (8 steps) เหมาะกับงาน Lofi/Piano ที่ไม่ต้องการ
# ดีเทลระดับสูงสุด ถ้าอยากลองรุ่นคุณภาพสูงกว่าแต่ช้ากว่า เปลี่ยนเป็น
# acestep_v1.5_xl_sft_bf16.safetensors หรือ acestep_v1.5_xl_base_bf16.safetensors
download_if_missing \
  "https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/split_files/diffusion_models/acestep_v1.5_xl_turbo_bf16.safetensors" \
  "$MODELS_DIR/diffusion_models/acestep_v1.5_xl_turbo_bf16.safetensors"

# ----------------------------------------------------------------------------
# ส่วนที่ 2: Text Encoder — 1.7B (แนะนำสำหรับ tier 12-16GB ตามเอกสารทางการ)
# ----------------------------------------------------------------------------
download_if_missing \
  "https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/split_files/text_encoders/qwen_1.7b_ace15.safetensors" \
  "$MODELS_DIR/text_encoders/qwen_1.7b_ace15.safetensors"

# ----------------------------------------------------------------------------
# ส่วนที่ 3: VAE
# ----------------------------------------------------------------------------
download_if_missing \
  "https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/split_files/vae/ace_1.5_vae.safetensors" \
  "$MODELS_DIR/vae/ace_1.5_vae.safetensors"

# ----------------------------------------------------------------------------
# ส่วนที่ 4: ติดตั้ง Custom Node ที่จำเป็นสำหรับ ACE-Step ใน ComfyUI
# ----------------------------------------------------------------------------
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"

if [ -d "$CUSTOM_NODES_DIR/ComfyUI_RyanOnTheInside" ]; then
  echo ">>> custom node ComfyUI_RyanOnTheInside มีอยู่แล้ว ข้ามการติดตั้ง"
else
  echo ">>> กำลังติดตั้ง custom node: ComfyUI_RyanOnTheInside"
  git clone https://github.com/ryanontheinside/ComfyUI_RyanOnTheInside.git \
    "$CUSTOM_NODES_DIR/ComfyUI_RyanOnTheInside"

  if [ -f "$CUSTOM_NODES_DIR/ComfyUI_RyanOnTheInside/requirements.txt" ]; then
    pip install -r "$CUSTOM_NODES_DIR/ComfyUI_RyanOnTheInside/requirements.txt" --break-system-packages
  fi
fi

# ----------------------------------------------------------------------------
# ส่วนที่ 5: โหลด Workflow ตัวอย่าง (text-to-music พื้นฐาน)
# ----------------------------------------------------------------------------
download_if_missing \
  "https://raw.githubusercontent.com/ryanontheinside/ComfyUI_RyanOnTheInside/main/examples/ace1.5/audio_ace_step_1_5_cover.json" \
  "$COMFY_DIR/user/default/workflows/audio_ace_step_1_5_cover.json"

# ----------------------------------------------------------------------------
# เสร็จสิ้น
# ----------------------------------------------------------------------------
echo "============================================================"
echo "โหลดโมเดล ACE-Step 1.5 XL (turbo) + text encoder + VAE"
echo "+ custom node + workflow ครบแล้ว"
echo "ComfyUI path: $COMFY_DIR"
echo "============================================================"
