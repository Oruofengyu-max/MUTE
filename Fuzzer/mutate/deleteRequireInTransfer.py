import os
import shutil
import re

def process_truffle_project(project_path, output_root):
    """
    处理单个 Truffle 项目：
    1. 找到 contracts 下的唯一 .sol 文件
    2. 如果包含 transfer 函数，移除其中所有 require 语句
    3. 复制整个项目到新目录
    4. 用修改后的代码覆盖新目录中的 .sol 文件
    """
    contracts_path = os.path.join(project_path, "contracts")
    if not os.path.exists(contracts_path):
        print(f"[跳过] {project_path} 没有 contracts 文件夹")
        return

    sol_files = [f for f in os.listdir(contracts_path) if f.endswith(".sol")]
    if len(sol_files) != 1:
        print(f"[跳过] {project_path} 中不是唯一的 .sol 文件: {sol_files}")
        return

    sol_file = sol_files[0]
    sol_path = os.path.join(contracts_path, sol_file)

    # 读取源代码
    with open(sol_path, "r", encoding="utf-8") as f:
        source_code = f.read()

    # 检查是否有 transfer 函数
    if "function transfer" not in source_code:
        print(f"[跳过] {sol_file} 没有 transfer 函数")
        return

    print(f"[处理] {sol_file} 包含 transfer 函数，删除 require")

    # 删除 transfer 函数内部的 require 行
    modified_code = remove_requires_in_transfer(source_code)

    # 复制整个项目到新目录
    project_name = os.path.basename(project_path)
    output_project_path = os.path.join(output_root, project_name)
    if os.path.exists(output_project_path):
        shutil.rmtree(output_project_path)
    shutil.copytree(project_path, output_project_path)

    # 覆盖新的 .sol 文件
    output_sol_path = os.path.join(output_project_path, "contracts", sol_file)
    with open(output_sol_path, "w", encoding="utf-8") as f:
        f.write(modified_code)

    print(f"[完成] 已保存修改后的项目到 {output_project_path}")


def remove_requires_in_transfer(source_code):
    """
    删除 Solidity 代码中 transfer / transferFrom 函数里的 require 行
    """
    lines = source_code.split("\n")
    new_lines = []
    inside_transfer = False
    brace_count = 0

    for line in lines:
        stripped = line.strip()

        # 检测 transfer 或 transferFrom 函数开始
        if re.match(r"function\s+transfer\s*\(", stripped) or re.match(r"function\s+transferFrom\s*\(", stripped):
            inside_transfer = True
            # 直接统计这一行里的大括号
            brace_count = line.count("{") - line.count("}")
            new_lines.append(line)
            continue

        if inside_transfer:
            # 统计大括号，判断函数范围
            brace_count += line.count("{") - line.count("}")
            if "require(" in stripped:
                print(f"    [删除] {stripped}")
                continue  # 跳过 require 行
            if brace_count <= 0:
                inside_transfer = False

        new_lines.append(line)

    return "\n".join(new_lines)


def main(batch_contracts_path, output_root):
    """
    遍历所有 Truffle 项目文件夹
    """
    if not os.path.exists(output_root):
        os.makedirs(output_root)

    for project in os.listdir(batch_contracts_path):
        project_path = os.path.join(batch_contracts_path, project)
        if os.path.isdir(project_path):
            process_truffle_project(project_path, output_root)


if __name__ == "__main__":
    # 输入目录：原始 BatchContracts
    batch_contracts_path = ""
    # 输出目录：修改后的项目集合
    output_root = ""

    main(batch_contracts_path, output_root)
