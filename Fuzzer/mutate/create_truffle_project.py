import os
import re
import shutil
import subprocess

SOURCE_DIR = ""  # 包含多个 .sol 文件的目录
TARGET_ROOT = ""  # 每个合约将变成一个子目录项目

TRUFFLE_INIT_TEMPLATE = "npx truffle init"

def extract_solc_version(sol_file_path):
    """
    从 Solidity 文件中提取第一个 pragma solidity 声明的版本字符串。
    返回值示例：'0.4.26' 或 '^0.5.16' 或 '>=0.6.0 <0.8.0'
    """
    with open(sol_file_path, 'r', encoding='utf-8') as f:
        for line in f:
            # 去除行末注释
            line = re.sub(r'//.*', '', line).strip()
            if line.startswith("pragma solidity"):
                # 匹配 version 部分（允许各种版本表达式）
                match = re.search(r'pragma\s+solidity\s+([^;]+);', line)
                if match:
                    version_str = match.group(1).strip()
                    return version_str
    return "^0.8.0"  # 默认 fallback



def create_truffle_project(sol_file, solc_version):
    name = os.path.splitext(sol_file)[0]
    project_path = os.path.join(TARGET_ROOT, name)

    print(f"📁 正在创建项目: {project_path} 使用版本: {solc_version}")

    # 创建项目目录
    if not os.path.exists(project_path):
        os.makedirs(project_path)

    # 初始化 truffle 项目
    subprocess.run(TRUFFLE_INIT_TEMPLATE, cwd=project_path, shell=True, check=True)

    # 创建 contracts 并移动合约
    contracts_dir = os.path.join(project_path, "contracts")
    shutil.copy(os.path.join(SOURCE_DIR, sol_file), contracts_dir)

    # 写入 truffle-config.js
    config_path = os.path.join(project_path, "truffle-config.js")
    with open(config_path, "a", encoding="utf-8") as f:
        f.write(f"""

module.exports.compilers = {{
  solc: {{
    version: "{solc_version}"
  }}
}};
""")


def main():
    if not os.path.exists(TARGET_ROOT):
        os.makedirs(TARGET_ROOT)

    for file in os.listdir(SOURCE_DIR):
        if file.endswith(".sol"):
            full_path = os.path.join(SOURCE_DIR, file)
            solc_version = extract_solc_version(full_path)
            create_truffle_project(file, solc_version)

    print("✅ 所有 Truffle 项目创建完毕！")


if __name__ == "__main__":
    main()
