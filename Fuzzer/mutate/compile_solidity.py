import os
import re
import subprocess
import shutil

# 输入和输出目录
input_dir = ""
output_dir = ""
os.makedirs(output_dir, exist_ok=True)

def extract_version(file_path):
    """
    扫描整个文件，提取 pragma solidity 版本。
    返回 (major, minor, patch, raw_version)
    - major/minor/patch 用于逻辑判断
    - raw_version 用于 solc-select
    """
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r'pragma\s+solidity\s+\^?(\d+)\.(\d+)\.(\d+)', content)
    if match:
        major, minor, patch = map(int, match.groups())
        raw_version = f"{major}.{minor}.{patch}"
        # 特殊规则：0.5.x → 逻辑上看作 5.x
        if major == 0 and minor == 5:
            return 5, minor, patch, raw_version
        return major, minor, patch, raw_version
    return None

def switch_solc_version(version_str):
    try:
        subprocess.run(["solc-select", "use", version_str], check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        print(f"[!] Failed to switch to solc version {version_str}")
        return False

def get_longest_runtime_bytecode(file_path):
    try:
        result = subprocess.run(
            ["solc", "--bin-runtime", file_path],
            capture_output=True, text=True, check=True
        )
        matches = re.findall(
            r'Binary of the runtime part:\s*([\da-fA-F]*)',
            result.stdout,
            flags=re.MULTILINE
        )
        return max(matches, key=len) if matches else None
    except subprocess.CalledProcessError:
        print(f"[!] Compilation failed for {file_path}")
        return None

# 主逻辑
for filename in os.listdir(input_dir):
    if filename.endswith(".sol"):
        file_path = os.path.join(input_dir, filename)

        version_info = extract_version(file_path)
        if not version_info:
            print(f"[!] No Solidity version found in {filename}")
            continue

        major, minor, patch, raw_version = version_info

        # ✅ 只保留逻辑上的 5.x (即 0.5.x)
        if major != 5:
            print(f"⏩ Skipping {filename}, version {raw_version} (not 0.5.x)")
            continue

        # 用 solc-select 切换回 0.5.x
        if not switch_solc_version(raw_version):
            continue

        print(f"[+] Compiling {filename} using Solidity {raw_version}")
        bytecode = get_longest_runtime_bytecode(file_path)

        if bytecode:
            base_name = os.path.splitext(filename)[0]
            hex_path = os.path.join(output_dir, f"{base_name}.hex")
            sol_path = os.path.join(output_dir, f"{base_name}.sol")

            with open(hex_path, "w") as out_hex:
                out_hex.write(bytecode)

            shutil.copy(file_path, sol_path)
            print(f"[✓] Saved {hex_path} and {sol_path}")
        else:
            print(f"[✗] No bytecode found in {filename}")
