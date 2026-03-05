#!/usr/bin/env bash
# 交互式脚本：从 JS 文件中提取 wb="data:application/octet-stream;base64,..." 的 base64，
# 解码为 .wasm，并尝试使用 wasm2wat 生成 .wat。脚本会提示用户输入 "I approve" 作为交互式授权。
#
# 用法：
#   ./extract_wasm_and_wat.sh [source-js-file] [outdir]
# 例如：
#   ./extract_wasm_and_wat.sh h5.worker_patch.js artifacts
#
set -euo pipefail

SRC="${1:-h5.worker_patch.js}"
OUTDIR="${2:-artifacts}"
BASENAME="$(basename "$SRC" | sed 's/\.[^.]*$//')"
WASM_OUT="$OUTDIR/${BASENAME}.wasm"
WAT_OUT="$OUTDIR/${BASENAME}.wat"

mkdir -p "$OUTDIR"

echo "Source file: $SRC"
echo "Output directory: $OUTDIR"
echo
echo "注意：此脚本会从 JS 文件中提取 embedded base64（形如 wb=\"data:application/octet-stream;base64,AAA...\"），"
echo "并解码为 .wasm。随后会尝试调用 wasm2wat（wabt 工具）生成 .wat。"
echo
read -r -p "请在此输入 'I approve' 以确认并继续： " CONFIRM
if [ "$CONFIRM" != "I approve" ]; then
  echo "未获得授权，退出。"
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "错误：未找到源文件 $SRC"
  exit 2
fi

# 提取 base64 blob（不包含前缀 data:..base64,）
B64="$(sed -n 's/.*wb=\"data:application\/octet-stream;base64,\([^"]*\)\".*/\1/p' "$SRC" || true)"

if [ -z "$B64" ]; then
  echo "未在 $SRC 中找到匹配的 base64 blob。请确认变量名/格式。"
  exit 3
fi

echo "提取到 base64 长度：${#B64}"
echo "正在解码为 WASM -> $WASM_OUT ..."
# 去除所有换行并解码
echo "$B64" | tr -d '\n' | base64 -d > "$WASM_OUT"

if [ ! -s "$WASM_OUT" ]; then
  echo "解码后的 wasm 文件为空或不存在。"
  exit 4
fi

echo "WASM 已生成：$(ls -lh "$WASM_OUT")"

# 查找 wasm2wat
if command -v wasm2wat >/dev/null 2>&1; then
  echo "找到 wasm2wat，开始转换 -> $WAT_OUT"
  wasm2wat "$WASM_OUT" -o "$WAT_OUT"
  echo "WAT 已生成：$(ls -lh "$WAT_OUT")"
  exit 0
fi

echo "未检测到 wasm2wat。尝试使用 apt-get 安装 wabt（需有 sudo 权限）。"
if command -v apt-get >/dev/null 2>&1; then
  if sudo apt-get update && sudo apt-get install -y wabt; then
    if command -v wasm2wat >/dev/null 2>&1; then
      echo "wasm2wat 安装成功，开始转换 -> $WAT_OUT"
      wasm2wat "$WASM_OUT" -o "$WAT_OUT"
      echo "WAT 已生成：$(ls -lh "$WAT_OUT")"
      exit 0
    fi
  else
    echo "apt-get 安装 wabt 失败或无权限。"
  fi
fi

echo "未能安装 wasm2wat / wabt。"
echo "你可以手动安装 wabt（例如在 Debian/Ubuntu 上：sudo apt-get install wabt），"
echo "或在 https://github.com/WebAssembly/wabt/releases 下载预构建工具，然后运行："
echo "  wasm2wat $WASM_OUT -o $WAT_OUT"
echo "脚本已完成（只生成了 $WASM_OUT）。"
exit 0
