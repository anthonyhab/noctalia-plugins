#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/shaders/frag"
OUT_DIR="${ROOT_DIR}/shaders/qsb"
QSB_VERSION=64

compile_with_qsb() {
    local frag_file="$1"
    local out_file="$2"
    qsb --qt6 --qsbversion "${QSB_VERSION}" -o "${out_file}" "${frag_file}"
}

compile_shader() {
    local frag_file="$1"
    local out_file="$2"

    if command -v qsb >/dev/null 2>&1; then
        compile_with_qsb "${frag_file}" "${out_file}"
        return 0
    fi

    if command -v nix >/dev/null 2>&1; then
        nix --extra-experimental-features "nix-command flakes" shell nixpkgs#qt6.qtshadertools -c qsb \
            --qt6 --qsbversion "${QSB_VERSION}" -o "${out_file}" "${frag_file}"
        return 0
    fi

    echo "error: qsb not found and nix is unavailable" >&2
    echo "install Qt ShaderTools or nix, then run this script again" >&2
    return 1
}

mkdir -p "${OUT_DIR}"

shopt -s nullglob
frag_files=("${SRC_DIR}"/*.frag)
shopt -u nullglob

if [ "${#frag_files[@]}" -eq 0 ]; then
    echo "error: no .frag files found in ${SRC_DIR}" >&2
    exit 1
fi

for frag_file in "${frag_files[@]}"; do
    base_name="$(basename "${frag_file}")"
    out_file="${OUT_DIR}/${base_name}.qsb"
    echo "building ${base_name} -> $(basename "${out_file}")"
    compile_shader "${frag_file}" "${out_file}"
done

echo "shader build complete"
