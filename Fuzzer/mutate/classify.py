#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ERC20智能合约漏洞分析工具 - 修复版
修复了transferFrom函数识别问题和函数名匹配问题，并增加TS漏洞检测（selfdestruct）
"""

import os
import re
import csv
import json
from pathlib import Path

# =====================
# 正则表达式模式 - 修复版
# =====================

# 编译所有需要的正则表达式
PATTERNS = {
    # 函数定义模式 - 修复版：支持多行，更灵活的匹配
    'function': re.compile(
        r'function\s+(\w+)\s*\([^)]*\)\s*'  # function name(params)
        r'(?:(?:public|private|internal|external)\s+)*'  # 访问修饰符
        r'(?:(?:view|pure|payable|nonpayable)\s+)*'  # 状态修饰符
        r'(?:(?:override|virtual)\s+)*'  # 其他修饰符
        r'(?:returns\s*\([^)]*\)\s*)?'  # 可选返回类型
        r'(?:\s*\{|\s*$)',  # 大括号或行结束
        re.IGNORECASE | re.MULTILINE
    ),

    # 更宽松的函数识别模式 - 专门处理跨行情况
    'function_multiline': re.compile(
        r'function\s+(\w+)\s*\([^)]*\)(?:[^{]*?)\{',
        re.IGNORECASE | re.DOTALL
    ),

    # Transfer事件模式
    'transfer_emit': re.compile(
        r'emit\s+Transfer\s*\(\s*([^,\s]+)\s*,\s*([^,\s]+)\s*,\s*([^)]+)\s*\)',
        re.IGNORECASE
    ),
    'transfer_direct': re.compile(
        r'Transfer\s*\(\s*([^,\s]+)\s*,\s*([^,\s]+)\s*,\s*([^)]+)\s*\)',
        re.IGNORECASE
    ),

    # 赋值操作模式
    'assignment': re.compile(
        r'(\w+(?:\[[\w\.\[\]]+\])?(?:\.\w+)?)\s*([\+\-\*\/\%]?=)\s*([^;]+);',
        re.IGNORECASE
    ),

    # selfdestruct模式 - 新增
    'selfdestruct': re.compile(
        r'\bselfdestruct\s*\(',
        re.IGNORECASE
    ),

    # 代码块匹配
    'block_start': re.compile(r'\{'),
    'block_end': re.compile(r'\}'),

    # 注释和字符串（用于清理）
    'single_comment': re.compile(r'//.*$', re.MULTILINE),
    'multi_comment': re.compile(r'/\*.*?\*/', re.DOTALL),
    'string_literal': re.compile(r'"[^"]*"'),

    # 映射和成员访问
    'mapping_access': re.compile(r'(\w+)\[([^\]]+)\]'),
    'member_access': re.compile(r'(\w+)\.(\w+)')
}


# =====================
# 代码预处理函数 - 增强版
# =====================

def clean_source_code(code):
    """预处理代码：移除注释和字符串，保持行结构"""
    # 移除多行注释
    code = PATTERNS['multi_comment'].sub(' ', code)
    # 移除单行注释
    code = PATTERNS['single_comment'].sub('', code)
    # 移除字符串字面量
    code = PATTERNS['string_literal'].sub('""', code)

    # 标准化空白符，但保持基本结构
    lines = code.split('\n')
    cleaned_lines = []
    for line in lines:
        # 移除行首行尾空白，但保留内部空格
        cleaned_line = line.strip()
        if cleaned_line:  # 只保留非空行
            cleaned_lines.append(cleaned_line)

    return '\n'.join(cleaned_lines)


def clean_variable_name(var_expr):
    """清理变量表达式，提取核心变量名"""
    var_expr = var_expr.strip()

    # 处理类型转换 address(0), uint256(amount) 等
    type_cast_match = re.match(r'\w+\s*\(\s*([^)]+)\s*\)', var_expr)
    if type_cast_match:
        var_expr = type_cast_match.group(1).strip()

    # 处理成员访问 msg.sender, this.balance 等
    member_match = PATTERNS['member_access'].match(var_expr)
    if member_match:
        return f"{member_match.group(1)}.{member_match.group(2)}"

    # 处理映射访问 balances[msg.sender] 等
    mapping_match = PATTERNS['mapping_access'].match(var_expr)
    if mapping_match:
        return mapping_match.group(1)  # 返回映射名称

    # 处理简单变量名
    simple_var_match = re.match(r'(\w+)', var_expr)
    if simple_var_match:
        return simple_var_match.group(1)

    return var_expr


def normalize_variable_name(var_name):
    """标准化变量名"""
    if not var_name:
        return ""

    # 去除前导下划线
    if var_name.startswith('_'):
        var_name = var_name[1:]

    # 处理映射访问，只保留映射名称
    if '[' in var_name:
        var_name = var_name.split('[')[0]

    # 处理成员访问
    if '.' in var_name:
        parts = var_name.split('.')
        if parts[0] in ['msg', 'block', 'tx']:
            return var_name
        else:
            return parts[-1]

    return var_name


def classify_variable_type(var_name):
    """分类变量类型"""
    if '[' in var_name:
        return 'mapping'
    elif '.' in var_name:
        return 'member'
    else:
        return 'variable'


def extract_function_name_from_signature(func_signature):
    """从函数签名中提取纯函数名

    Args:
        func_signature: 如 "burn(uint256)" 或 "transferFrom(address,address,uint256)" 或 "burn"

    Returns:
        str: 纯函数名，如 "burn", "transferFrom"
    """
    if '(' in func_signature:
        return func_signature.split('(')[0].strip()
    else:
        return func_signature.strip()


# =====================
# 函数提取 - 增强版
# =====================

def find_function_boundaries(cleaned_code, func_name, start_pos):
    """找到函数的边界位置"""
    lines = cleaned_code.split('\n')
    start_line = -1

    # 找到函数开始行
    for i, line in enumerate(lines):
        if f'function {func_name}' in line and i * 50 >= start_pos:  # 大致估算位置
            start_line = i
            break

    if start_line == -1:
        return None

    # 找到函数体开始的大括号
    brace_line = start_line
    for i in range(start_line, len(lines)):
        if '{' in lines[i]:
            brace_line = i
            break

    # 计算大括号匹配，找到函数结束
    brace_count = 0
    end_line = brace_line

    for i in range(brace_line, len(lines)):
        line = lines[i]
        brace_count += line.count('{')
        brace_count -= line.count('}')

        if brace_count == 0 and i > brace_line:
            end_line = i
            break

    return {
        'start_line': start_line + 1,
        'end_line': end_line + 1,
        'source_lines': lines[start_line:end_line + 1]
    }


def extract_function_code_enhanced(cleaned_code, func_name, start_pos):
    """增强版函数代码提取"""
    boundaries = find_function_boundaries(cleaned_code, func_name, start_pos)

    if not boundaries:
        return None

    return {
        'name': func_name,
        'start_line': boundaries['start_line'],
        'end_line': boundaries['end_line'],
        'source_code': '\n'.join(boundaries['source_lines']),
        'transfers': [],
        'assignments': [],
        'has_selfdestruct': False,  # 新增：是否包含selfdestruct
        'selfdestruct_lines': []  # 新增：selfdestruct所在行号
    }


def parse_contract_functions(source_code, contract_name, verbose=True):
    """解析合约源码，提取所有函数 - 增强版"""
    if verbose:
        print(f"    📋 解析合约源码...")

    # 预处理代码
    cleaned_code = clean_source_code(source_code)

    if verbose:
        print(f"    🔍 代码清理完成，代码行数: {len(cleaned_code.split())}")

    functions = {}

    # 使用两种模式尝试匹配函数
    patterns_to_try = ['function', 'function_multiline']

    for pattern_name in patterns_to_try:
        if verbose and pattern_name == 'function_multiline':
            print(f"    🔄 使用多行模式重新扫描...")

        pattern = PATTERNS[pattern_name]
        matches = pattern.finditer(cleaned_code)

        for match in matches:
            func_name = match.group(1)

            # 跳过已经找到的函数
            if func_name in functions:
                continue

            start_pos = match.start()

            # 提取函数代码
            func_info = extract_function_code_enhanced(cleaned_code, func_name, start_pos)

            if func_info:
                # 分析函数内容
                analyze_function_content(func_info, verbose=False)
                functions[func_name] = func_info

                if verbose:
                    transfer_count = len(func_info['transfers'])
                    assignment_count = len(func_info['assignments'])
                    selfdestruct_status = "✋" if func_info['has_selfdestruct'] else ""
                    print(
                        f"      🔍 函数 '{func_name}': {transfer_count}个Transfer事件, {assignment_count}个赋值操作 {selfdestruct_status}")

    if verbose:
        print(f"    ✅ 发现 {len(functions)} 个函数: {', '.join(functions.keys())}")

    return functions


def analyze_function_content(func_info, verbose=False):
    """分析函数内容，提取Transfer事件、赋值操作和selfdestruct"""
    lines = func_info['source_code'].split('\n')

    for line_idx, line in enumerate(lines):
        actual_line_number = func_info['start_line'] + line_idx

        # 查找Transfer事件
        find_transfer_events_in_line(line, actual_line_number, func_info)

        # 查找赋值操作
        find_assignments_in_line(line, actual_line_number, func_info)

        # 查找selfdestruct - 新增
        find_selfdestruct_in_line(line, actual_line_number, func_info)


def find_transfer_events_in_line(line, line_number, func_info):
    """在代码行中查找Transfer事件"""
    # 尝试匹配 emit Transfer(...) 格式
    match = PATTERNS['transfer_emit'].search(line)
    if not match:
        # 尝试匹配直接 Transfer(...) 格式
        match = PATTERNS['transfer_direct'].search(line)

    if match:
        from_var = clean_variable_name(match.group(1))
        to_var = clean_variable_name(match.group(2))
        amount_var = clean_variable_name(match.group(3))

        transfer = {
            'from_var': from_var,
            'to_var': to_var,
            'amount_var': amount_var,
            'line_number': line_number,
            'context': line.strip()
        }

        func_info['transfers'].append(transfer)


def find_assignments_in_line(line, line_number, func_info):
    """在代码行中查找赋值操作"""
    matches = PATTERNS['assignment'].findall(line)

    for match in matches:
        var_name = match[0].strip()
        operator = match[1].strip()

        assignment = {
            'variable': var_name,
            'var_type': classify_variable_type(var_name),
            'operator': operator,
            'line_number': line_number,
            'context': line.strip()
        }

        func_info['assignments'].append(assignment)


def find_selfdestruct_in_line(line, line_number, func_info):
    """在代码行中查找selfdestruct - 新增函数"""
    if PATTERNS['selfdestruct'].search(line):
        func_info['has_selfdestruct'] = True
        func_info['selfdestruct_lines'].append({
            'line_number': line_number,
            'context': line.strip()
        })


# =====================
# 漏洞分析函数
# =====================

def extract_transfer_variables(transfers):
    """提取Transfer事件中使用的变量"""
    variables = {
        'amounts': set(),
        'addresses': set()
    }

    for transfer in transfers:
        if transfer.get('amount_var'):
            normalized = normalize_variable_name(transfer['amount_var'])
            variables['amounts'].add(normalized)

        if transfer.get('from_var'):
            normalized = normalize_variable_name(transfer['from_var'])
            variables['addresses'].add(normalized)

        if transfer.get('to_var'):
            normalized = normalize_variable_name(transfer['to_var'])
            variables['addresses'].add(normalized)

    return variables


def check_variable_modifications(assignments, target_vars):
    """检查赋值操作是否修改了目标变量"""
    modified = {
        'amounts': [],
        'addresses': []
    }

    for assignment in assignments:
        var_name = normalize_variable_name(assignment['variable'])

        # 检查是否修改了金额变量
        if is_variable_match(var_name, target_vars['amounts']):
            modified['amounts'].append(assignment['variable'])

        # 检查是否修改了地址变量
        if is_variable_match(var_name, target_vars['addresses']):
            modified['addresses'].append(assignment['variable'])

    return modified


def is_variable_match(var_name, target_vars):
    """检查变量是否匹配目标变量集合"""
    if var_name in target_vars:
        return True

    # 模糊匹配：检查是否有相似的变量名
    for target in target_vars:
        if are_similar_variables(var_name, target):
            return True

    return False


def are_similar_variables(var1, var2):
    """检查两个变量名是否相似"""
    if var1 == var2:
        return True

    # 标准化比较（去除下划线，转小写）
    norm1 = var1.replace('_', '').lower()
    norm2 = var2.replace('_', '').lower()

    return norm1 == norm2


def analyze_function_pair(func_a, func_b, verbose=True):
    """分析两个函数之间的漏洞关系 - 增加TS漏洞检测，优先级：TS > TA > TR > TT"""

    if verbose:
        print(f"        🔄 分析函数对: {func_a['name']} vs {func_b['name']}")

    # 首先检查TS漏洞（最高优先级）
    if func_a['has_selfdestruct'] or func_b['has_selfdestruct']:
        affected_function = func_a['name'] if func_a['has_selfdestruct'] else func_b['name']
        result = {
            'type': 'TS',
            'description': f"TS漏洞: {affected_function}包含selfdestruct调用，存在自毁风险",
            'affected_variables': [],
            'confidence': 'HIGH',
            'source_function': func_a['name'],
            'target_function': func_b['name'],
            'selfdestruct_function': affected_function
        }

        if verbose:
            print(f"        🔥 检测到 TS漏洞 (自毁漏洞) - HIGH")
            print(f"        💣 包含selfdestruct的函数: {affected_function}")

        return result

    # 如果没有TS漏洞，按原有逻辑检查其他漏洞类型
    # 分别检查A->B和B->A的漏洞关系，选择最严重的
    result_a_to_b = check_vulnerability_between_functions(func_a, func_b, verbose)
    result_b_to_a = check_vulnerability_between_functions(func_b, func_a, verbose)

    # 优先级：TA > TR > TT，选择最严重的漏洞类型
    if result_a_to_b['type'] == 'TA' or result_b_to_a['type'] == 'TA':
        selected_result = result_a_to_b if result_a_to_b['type'] == 'TA' else result_b_to_a
    elif result_a_to_b['type'] == 'TR' or result_b_to_a['type'] == 'TR':
        selected_result = result_a_to_b if result_a_to_b['type'] == 'TR' else result_b_to_a
    else:
        # 如果都是TT，返回第一个结果
        selected_result = result_a_to_b

    if verbose:
        vuln_type = selected_result['type']
        confidence = selected_result['confidence']

        if vuln_type == 'TA':
            print(f"        ⚠️  检测到 TA漏洞 (金额变量冲突) - {confidence}")
        elif vuln_type == 'TR':
            print(f"        ⚠️  检测到 TR漏洞 (地址变量冲突) - {confidence}")
        else:
            print(f"        ℹ️  检测到 TT漏洞 (交互风险) - {confidence}")

        if selected_result.get('affected_variables'):
            print(f"        📍 影响变量: {', '.join(selected_result['affected_variables'])}")

    return selected_result


def check_vulnerability_between_functions(source_func, target_func, verbose=False):
    """检查源函数是否影响目标函数 - 新的检测逻辑"""

    # 提取目标函数中的Transfer事件变量
    target_transfer_vars = extract_transfer_variables(target_func['transfers'])

    # 检查源函数是否修改了目标函数的Transfer变量
    if target_transfer_vars['amounts'] or target_transfer_vars['addresses']:
        modified_vars = check_variable_modifications(source_func['assignments'], target_transfer_vars)

        # 按优先级检测漏洞类型
        if modified_vars['amounts']:
            return {
                'type': 'TA',
                'description': f"TA漏洞: {source_func['name']}修改了{target_func['name']}的交易金额变量",
                'affected_variables': modified_vars['amounts'],
                'confidence': 'HIGH',
                'source_function': source_func['name'],
                'target_function': target_func['name']
            }

        if modified_vars['addresses']:
            return {
                'type': 'TR',
                'description': f"TR漏洞: {source_func['name']}修改了{target_func['name']}的交易对象变量",
                'affected_variables': modified_vars['addresses'],
                'confidence': 'HIGH',
                'source_function': source_func['name'],
                'target_function': target_func['name']
            }

    # 如果没有检测到TA或TR，则归类为TT漏洞
    return {
        'type': 'TT',
        'description': f"TT漏洞: {source_func['name']}和{target_func['name']}存在潜在交互风险",
        'affected_variables': [],
        'confidence': 'MEDIUM',
        'source_function': source_func['name'],
        'target_function': target_func['name']
    }


# =====================
# 配置文件处理
# =====================

def load_function_pairs(project_path, verbose=True):
    """加载函数对配置"""
    csv_file = Path(project_path) / "vulnerable_pairs.csv"
    if not csv_file.exists():
        if verbose:
            print(f"    ❌ 未找到配置文件: vulnerable_pairs.csv")
        return []

    pairs = []
    try:
        with open(csv_file, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                func1 = (row.get("Function1") or row.get("Source Function") or
                         row.get("source_function") or row.get("SourceFunction") or "").strip()
                func2 = (row.get("Function2") or row.get("Target Function") or
                         row.get("target_function") or row.get("TargetFunction") or "").strip()

                if func1 and func2:
                    pairs.append((func1, func2))

        if verbose:
            print(f"    ✅ 加载函数对配置: {len(pairs)} 个函数对")
            for func1, func2 in pairs:
                print(f"      📌 {func1} <-> {func2}")

    except Exception as e:
        if verbose:
            print(f"    ❌ 读取配置文件失败: {e}")
        pass

    return pairs




# =====================
# 项目分析函数
# =====================

def analyze_single_truffle_project(project_path, verbose=True):
    """分析单个Truffle项目 - 修复函数名匹配问题，增加TS漏洞检测"""
    project_path = Path(project_path)

    if verbose:
        print(f"  📁 项目路径: {project_path}")

    # 查找contracts目录下的.sol文件
    contracts_dir = project_path / "contracts"
    if not contracts_dir.exists():
        if verbose:
            print(f"    ❌ contracts目录不存在")
        return {"status": "no_contracts"}

    sol_files = list(contracts_dir.glob("*.sol"))
    if not sol_files:
        if verbose:
            print(f"    ❌ 未找到.sol文件")
        return {"status": "no_contracts"}

    if verbose:
        print(f"    📄 发现 {len(sol_files)} 个合约文件:")
        for sol_file in sol_files:
            print(f"      - {sol_file.name}")

    # 加载函数对配置
    pairs = load_function_pairs(project_path, verbose)
    if not pairs:
        if verbose:
            print(f"    ❌ 无函数对配置，跳过分析")
        return {"status": "no_pairs"}

    results = {
        "status": "analyzed",
        "contracts": {},
        "vulnerabilities": {}
    }

    # 分析每个合约文件
    for sol_file in sol_files:
        contract_name = sol_file.stem

        # 跳过Migrations合约
        if contract_name.lower() == "migrations":
            if verbose:
                print(f"    ⏭️  跳过Migrations合约")
            continue

        if verbose:
            print(f"    🔍 分析合约: {contract_name}")

        try:
            with open(sol_file, 'r', encoding='utf-8') as f:
                source_code = f.read()

            if verbose:
                print(f"      📊 合约代码长度: {len(source_code)} 字符")

            functions = parse_contract_functions(source_code, contract_name, verbose)
            results["contracts"][contract_name] = {
                "file": str(sol_file.relative_to(project_path)),
                "functions": list(functions.keys())
            }

            # 分析函数对 - 修复函数名匹配问题，增加TS漏洞检测
            if verbose:
                print(f"    🎯 开始函数对漏洞分析...")

            vuln_count = {'TS': 0, 'TA': 0, 'TR': 0, 'TT': 0}  # 增加TS计数

            for func_a_name, func_b_name in pairs:
                # 提取纯函数名进行匹配
                pure_func_a = extract_function_name_from_signature(func_a_name)
                pure_func_b = extract_function_name_from_signature(func_b_name)

                if verbose:
                    print(f"        🔍 检查函数对:")
                    print(f"          配置签名: {func_a_name} <-> {func_b_name}")
                    print(f"          提取函数名: {pure_func_a} <-> {pure_func_b}")
                    print(f"          可用函数: {list(functions.keys())}")

                if pure_func_a in functions and pure_func_b in functions:
                    pair_key = f"{contract_name}:{pure_func_a}_vs_{pure_func_b}"
                    vuln_result = analyze_function_pair(
                        functions[pure_func_a], functions[pure_func_b], verbose
                    )
                    results["vulnerabilities"][pair_key] = vuln_result
                    vuln_count[vuln_result['type']] += 1

                    if verbose:
                        print(f"        ✅ 成功分析函数对: {pure_func_a} vs {pure_func_b}")
                else:
                    if verbose:
                        missing_funcs = []
                        if pure_func_a not in functions:
                            missing_funcs.append(f"{pure_func_a} (从 {func_a_name} 提取)")
                        if pure_func_b not in functions:
                            missing_funcs.append(f"{pure_func_b} (从 {func_b_name} 提取)")
                        print(f"        ⚠️  跳过函数对: 缺少函数 {', '.join(missing_funcs)}")

            if verbose:
                total_vulns = sum(vuln_count.values())
                print(
                    f"    📈 漏洞统计: TS={vuln_count['TS']}, TA={vuln_count['TA']}, TR={vuln_count['TR']}, TT={vuln_count['TT']}, 总计={total_vulns}")

        except Exception as e:
            if verbose:
                print(f"    ❌ 合约分析失败: {e}")
            continue  # 跳过有问题的合约文件

    if verbose:
        total_vulnerabilities = len(results["vulnerabilities"])
        print(f"    ✅ 项目分析完成，发现 {total_vulnerabilities} 个漏洞")

    return results


def analyze_truffle_projects(root_path, max_projects=None, verbose=True):
    """分析Truffle项目集合"""
    root_path = Path(root_path)
    if not root_path.exists():
        error_msg = f"错误: 路径不存在 {root_path}"
        print(error_msg)
        return {"status": "error", "error": error_msg}

    # 查找所有项目目录
    project_dirs = [d for d in root_path.iterdir() if d.is_dir()]
    if max_projects:
        project_dirs = project_dirs[:max_projects]

    print(f"🚀 开始分析 {len(project_dirs)} 个Truffle项目...")
    print(f"📂 根目录: {root_path}")

    if max_projects:
        print(f"🔢 限制分析数量: {max_projects}")

    results = {
        "summary": {
            "total_projects": len(project_dirs),
            "analyzed": 0,
            "ts_vulnerabilities": 0,  # 新增TS漏洞统计
            "ta_vulnerabilities": 0,
            "tr_vulnerabilities": 0,
            "tt_cases": 0,
            "errors": 0,
            "no_contracts": 0,
            "no_pairs": 0
        },
        "projects": {}
    }

    for i, project_dir in enumerate(project_dirs, 1):
        project_name = project_dir.name
        print(f"\n{'=' * 50}")
        print(f"[{i}/{len(project_dirs)}] 🔍 分析项目: {project_name}")
        print(f"{'=' * 50}")

        try:
            result = analyze_single_truffle_project(project_dir, verbose)
            results["projects"][project_name] = result

            # 更新统计
            if result["status"] == "analyzed":
                results["summary"]["analyzed"] += 1

                # 统计漏洞类型
                for vuln in result.get("vulnerabilities", {}).values():
                    vuln_type = vuln.get("type", "")
                    if vuln_type == "TS":
                        results["summary"]["ts_vulnerabilities"] += 1
                    elif vuln_type == "TA":
                        results["summary"]["ta_vulnerabilities"] += 1
                    elif vuln_type == "TR":
                        results["summary"]["tr_vulnerabilities"] += 1
                    elif vuln_type == "TT":
                        results["summary"]["tt_cases"] += 1

                print(f"✅ 项目 {project_name} 分析成功")

            elif result["status"] == "no_contracts":
                results["summary"]["no_contracts"] += 1
                print(f"⚠️  项目 {project_name} 无合约文件")

            elif result["status"] == "no_pairs":
                results["summary"]["no_pairs"] += 1
                print(f"⚠️  项目 {project_name} 无配置文件")
            else:
                results["summary"]["errors"] += 1
                print(f"❌ 项目 {project_name} 分析失败")

        except Exception as e:
            print(f"❌ 项目 {project_name} 发生异常: {e}")
            if verbose:
                import traceback
                traceback.print_exc()
            results["projects"][project_name] = {"status": "error", "error": str(e)}
            results["summary"]["errors"] += 1

    return results


def print_analysis_summary(results):
    """打印分析结果摘要 - 增加TS漏洞显示"""
    summary = results["summary"]

    print(f"\n{'=' * 60}")
    print(f"📊 ERC20漏洞分析结果摘要")
    print(f"{'=' * 60}")
    print(f"总项目数: {summary['total_projects']}")
    print(f"成功分析: {summary['analyzed']}")
    print(f"")
    print(f"🔍 漏洞检测结果:")
    print(f"  🔥 TS漏洞 (自毁漏洞): {summary['ts_vulnerabilities']}")
    print(f"  ⚠️  TA漏洞 (交易金额漏洞): {summary['ta_vulnerabilities']}")
    print(f"  ⚠️  TR漏洞 (交易对象漏洞): {summary['tr_vulnerabilities']}")
    print(f"  ℹ️  TT漏洞 (交互风险漏洞): {summary['tt_cases']}")

    total_vulns = summary['ts_vulnerabilities'] + summary['ta_vulnerabilities'] + summary['tr_vulnerabilities'] + \
                  summary['tt_cases']
    print(f"  🎯 总漏洞数: {total_vulns}")
    print(f"")
    print(f"📈 项目状态统计:")
    print(f"  📄 无合约文件: {summary['no_contracts']}")
    print(f"  📝 无配置文件: {summary['no_pairs']}")
    print(f"  ❌ 分析错误: {summary['errors']}")

    if summary['analyzed'] > 0:
        success_rate = (summary['analyzed'] / summary['total_projects']) * 100
        ts_rate = (summary['ts_vulnerabilities'] / max(total_vulns, 1)) * 100
        ta_rate = (summary['ta_vulnerabilities'] / max(total_vulns, 1)) * 100
        tr_rate = (summary['tr_vulnerabilities'] / max(total_vulns, 1)) * 100
        tt_rate = (summary['tt_cases'] / max(total_vulns, 1)) * 100

        print(f"")
        print(f"📊 分析效率:")
        print(f"  ✅ 项目分析成功率: {success_rate:.1f}%")
        print(f"")
        print(f"📈 漏洞类型分布:")
        print(f"  TS漏洞占比: {ts_rate:.1f}%")
        print(f"  TA漏洞占比: {ta_rate:.1f}%")
        print(f"  TR漏洞占比: {tr_rate:.1f}%")
        print(f"  TT漏洞占比: {tt_rate:.1f}%")

    print(f"{'=' * 60}")

    # 显示详细的漏洞分布情况
    if summary['analyzed'] > 0:
        projects = results.get("projects", {})
        vuln_projects = 0
        total_function_pairs = 0

        print(f"\n🔍 详细统计:")

        for project_name, project_result in projects.items():
            if project_result.get("status") == "analyzed":
                vulns = project_result.get("vulnerabilities", {})
                if vulns:
                    vuln_projects += 1
                    total_function_pairs += len(vulns)

        print(f"  📁 包含漏洞的项目: {vuln_projects}/{summary['analyzed']}")
        print(f"  🔄 分析的函数对总数: {total_function_pairs}")
        if summary['analyzed'] > 0:
            print(f"  📊 平均每项目函数对数: {total_function_pairs / summary['analyzed']:.1f}")

        # 显示无漏洞项目的可能原因
        no_vuln_projects = summary['analyzed'] - vuln_projects
        if no_vuln_projects > 0:
            print(f"\n❓ 无漏洞项目分析 ({no_vuln_projects}个):")
            print(f"  可能原因:")
            print(f"  1. 合约代码质量较好，遵循安全最佳实践")
            print(f"  2. 合约功能简单，攻击面较小")
            print(f"  3. 静态分析工具检测范围限制")
            print(f"  4. 函数对配置不完整或不匹配")

        # 如果发现TS漏洞，给出特别提醒
        if summary['ts_vulnerabilities'] > 0:
            print(f"\n🔥 TS漏洞特别提醒:")
            print(f"  检测到 {summary['ts_vulnerabilities']} 个TS漏洞（自毁漏洞）")
            print(f"  这类漏洞风险极高，可能导致合约被恶意销毁")
            print(f"  建议立即审查包含selfdestruct的函数调用逻辑")

        print()


# =====================
# 主程序入口
# =====================

if __name__ == "__main__":
    # ==============================================
    # 在这里设置你的Truffle项目集合路径
    # ==============================================

    # 修改这里为你的实际路径
    TRUFFLE_PROJECTS_ROOT = ""

    # 可选参数
    MAX_PROJECTS = None  # None表示分析所有项目，或设置具体数字如50
    SAVE_RESULTS = True  # 是否保存结果到JSON文件
    VERBOSE_OUTPUT = True  # 是否显示详细输出

    # ==============================================
    # 开始分析
    # ==============================================

    print("🔍 ERC20智能合约漏洞分析工具 - 完全修复版（含TS漏洞检测）")
    print(f"📂 分析路径: {TRUFFLE_PROJECTS_ROOT}")

    if MAX_PROJECTS:
        print(f"🔢 最大分析项目数: {MAX_PROJECTS}")

    try:
        # 执行分析
        results = analyze_truffle_projects(TRUFFLE_PROJECTS_ROOT, MAX_PROJECTS, VERBOSE_OUTPUT)

        # 打印摘要
        print_analysis_summary(results)

        # 保存结果
        if SAVE_RESULTS:
            output_file = Path(TRUFFLE_PROJECTS_ROOT) / "vulnerability_analysis_results_with_ts.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(results, f, ensure_ascii=False, indent=2)
            print(f"\n💾 详细结果已保存到: {output_file}")

        print(f"\n🎉 分析完成!")

    except Exception as e:
        print(f"💥 分析失败: {e}")
        import traceback

        traceback.print_exc()

    input("\n⌨️  按Enter键退出...")