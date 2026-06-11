#!/bin/bash

# 遇到任何错误时立即终止脚本执行
set -e

# 定义用于显示错误信息并退出的函数
#
# 参数:
#   $1 - 错误消息内容
# 返回:
#   以退出码 1 结束当前脚本
error_exit() {
  echo "❌ 错误: $1" >&2
  exit 1
}

# 定义自动发布的核心业务逻辑函数
#
# 依次执行以下步骤：
# 1. 检查当前分支是否为主分支 main
# 2. 检查网络与远程仓库的连接状态
# 3. 检查本地分支是否滞后于远程分支
# 4. 运行 Dart 脚本自动递增 pubspec.yaml 中的版本号与构建号
# 5. 自动添加全部变更并提交 Git 记录
# 6. 为当前提交打上对应的版本号 Tag
# 7. 将本地提交与 Tag 推送至 GitHub，从而触发 Actions 在线编译
run_publish() {
  # 获取当前 Git 分支名称
  CURRENT_BRANCH=$(git branch --show-current)
  if [ "$CURRENT_BRANCH" != "main" ]; then
    error_exit "发布新版必须在 main 分支上进行，当前分支是: $CURRENT_BRANCH"
  fi

  # 检查远程连接
  echo "📡 正在检查与远程仓库的连接..."
  git fetch origin || error_exit "无法连接到远程仓库，请检查网络连接或 Git 权限。"

  # 检查本地分支状态是否落后于远程分支
  LOCAL_STATUS=$(git status -uno)
  if [[ $LOCAL_STATUS == *"behind"* ]]; then
    error_exit "本地分支已落后于远程分支，请先执行 git pull 同步代码。"
  fi

  echo "🆙 开始递增版本号..."
  # 运行 Dart 脚本进行版本号自增并获取新的版本号
  NEW_VERSION=$(dart tool/bump_version.dart)
  
  if [ -z "$NEW_VERSION" ]; then
    error_exit "递增版本号失败！"
  fi

  echo "✅ 成功递增版本号为: $NEW_VERSION"

  # 提交所有更改（包括自动修改的 pubspec.yaml 及其他未提交文件）
  echo "📦 正在将改动添加到暂存区并提交..."
  git add .
  
  # 检查是否有文件发生了变化需要提交
  if ! git diff-index --quiet HEAD --; then
    git commit -m "chore: release v$NEW_VERSION"
    echo "✅ 成功提交变更: chore: release v$NEW_VERSION"
  else
    echo "⚠️ 警告: 未检测到任何代码改动，将直接使用当前的 HEAD 提交打标签。"
  fi

  # 准备并创建 Git Tag
  TAG_NAME="v$NEW_VERSION"
  echo "🏷️  正在创建 Git 标签: $TAG_NAME..."
  
  # 检查该标签是否在本地或远程已存在
  if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    error_exit "Git 标签 $TAG_NAME 已存在，请检查版本配置。"
  fi
  
  git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
  echo "✅ 成功创建本地标签: $TAG_NAME"

  # 推送分支及标签至 GitHub
  echo "🚀 正在推送代码至 origin main 分支..."
  git push origin main
  
  echo "🚀 正在推送标签至 origin..."
  git push origin "$TAG_NAME"

  echo "🎉 发布流程本地阶段已全部完成！"
  echo "✨ 标签 $TAG_NAME 已成功推送到 GitHub。"
  echo "⚙️  GitHub Actions 现已触发，将在线编译并发布 macOS 和 Windows 安装包至 Release 页面。"
}

# 执行主逻辑
run_publish
