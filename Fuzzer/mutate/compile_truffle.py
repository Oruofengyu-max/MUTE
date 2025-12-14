import os
import subprocess

# 配置路径（修改为你实际的路径）
INPUT_DIR = ""

def is_truffle_project(path):
    return os.path.isfile(os.path.join(path, "truffle-config.js"))

def compile_truffle_project(project_path):
    print(f"📦 正在编译: {project_path}")
    try:
        # --all 表示强制重新编译，即使存在 build/
        subprocess.run("npx truffle compile --all", shell=True, cwd=project_path, check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding='utf-8')
        print(f"✅ 编译成功: {os.path.basename(project_path)}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ 编译失败: {os.path.basename(project_path)}")
        print(e.stderr)
        return False

def main():
    if not os.path.exists(INPUT_DIR):
        print(f"❌ 输入目录不存在: {INPUT_DIR}")
        return

    total = 0
    compiled = 0
    failed = 0

    for item in os.listdir(INPUT_DIR):
        project_path = os.path.join(INPUT_DIR, item)
        if os.path.isdir(project_path) and is_truffle_project(project_path):
            total += 1
            if compile_truffle_project(project_path):
                compiled += 1
            else:
                failed += 1

    print("\n🎉 完成任务")
    print(f"总项目数: {total}")
    print(f"成功编译: {compiled}")
    print(f"失败: {failed}")

if __name__ == "__main__":
    main()
