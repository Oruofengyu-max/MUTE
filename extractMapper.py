import os
import subprocess
import pandas as pd
import re

def get_solidity_version(file_path):
    """
    从合约文件中提取 pragma Solidity 版本
    """
    print("Current working directory:", os.getcwd())
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
        # 使用正则表达式提取 pragma solidity 版本
        match = re.search(r'pragma solidity \^?([0-9]+\.[0-9]+\.[0-9]+);', content)
        if match:
            return match.group(1)
        else:
            print("Failed to detect Solidity version from the pragma statement.")
            return None

def switch_solc_version(version):
    """
    使用 solc-select 切换到指定的 Solidity 版本
    """
    try:
        subprocess.run(['solc-select', 'use', version], check=True)
        print(f"Switched to solc version {version}")
    except subprocess.CalledProcessError as e:
        print(f"Error switching to solc version {version}: {e.stderr}")

def extractMapper(path, fileName):
    # 修改当前工作目录
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), path)
    os.chdir(path)

    # 获取合约文件中的 Solidity 版本
    solidity_version = get_solidity_version(fileName)
    if solidity_version is None:
        print("No valid Solidity version found. Exiting.")
        return

    # 切换到对应的 solc 版本
    switch_solc_version(solidity_version)

    # 读取 RaW-edge.csv 文件
    raw_edge_path = "RaW-edge.csv"
    raw_edges = pd.read_csv(raw_edge_path, header=None, names=["Source", "Target"])

    # 读取 contract.tac 文件
    tac_file_path = "contract.tac"
    with open(tac_file_path, "r") as tac_file:
        tac_lines = tac_file.readlines()

    # 映射每个块到对应的函数名或哈希值
    block_to_function = {}
    current_function = None

    for line in tac_lines:
        # 匹配函数声明
        function_match = re.match(r"function\s+([a-zA-Z0-9_]+)\((.*?)\)\s+.*", line)
        if function_match:
            current_function = function_match.group(1)  # 提取函数名
        # 匹配块声明
        block_match = re.match(r"Begin block\s+(.*)", line.strip())
        if block_match and current_function:
            block_to_function[block_match.group(1)] = current_function

    # 映射 Source 和 Target 到函数名
    mapped_edges = []
    for _, row in raw_edges.iterrows():
        source_block = row["Source"]
        target_block = row["Target"]
        source_function = block_to_function.get(source_block, "Unknown")
        target_function = block_to_function.get(target_block, "Unknown")
        mapped_edges.append([source_function, target_function])

    # 转换为 DataFrame
    mapped_df = pd.DataFrame(mapped_edges, columns=["Source Function", "Target Function"])

    # 使用 solc 提取函数名对应的哈希值
    solc_command = ["solc", "--hashes", fileName]
    try:
        # 调用 solc 获取函数哈希
        result = subprocess.run(solc_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output = result.stdout

        # 提取函数名与哈希值的对应关系
        function_to_hash = {}
        for line in output.splitlines():
            match = re.match(r"([a-fA-F0-9]{8}):\s+([^\(]+\(.*\))", line)
            if match:
                function_hash = match.group(1)
                function_name = match.group(2).strip()
                function_to_hash[function_name] = function_hash

        # 替换 Mapped-RaW-edges.csv 中的函数名为哈希值
        for index, row in mapped_df.iterrows():
            source_function = row["Source Function"]
            target_function = row["Target Function"]
            if source_function.startswith("0x"):
                source_function = source_function[2:]  # 去掉前缀 "0x"
            if target_function.startswith("0x"):
                target_function = target_function[2:]  # 去掉前缀 "0x"
            # 替换为哈希值
            source_function = str(source_function)
            target_function = str(target_function)
            reversed_function_to_hash = {value: key for key, value in function_to_hash.items()}
            x = reversed_function_to_hash.get(source_function)
            y = reversed_function_to_hash.get(target_function)
            mapped_df.loc[index, "Source Function"] = x
            mapped_df.loc[index, "Target Function"] = y

        # 保存结果到 Mapped-RaW-edges.csv

        # 1. 去掉包含 None 值的行
        filtered_df = mapped_df.dropna()

        filtered_df = filtered_df[filtered_df['Source Function'] != filtered_df['Target Function']]

        # 2. 去重
        filtered_df = filtered_df.drop_duplicates()
        print("filtered_df.size() =", filtered_df.size)
        filtered_df.to_csv("Mapped-RaW-edges.csv", index=False)
        print("映射完成，结果已保存到 'Mapped-RaW-edges.csv'")

    except Exception as e:
        print("执行 solc 命令失败：", e)


