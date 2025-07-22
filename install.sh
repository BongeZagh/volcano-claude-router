#!/bin/bash

set -e

# --- 1. Node.js 安装 (保持不变，已在你的脚本中处理) ---
install_nodejs() {
    local platform=$(uname -s)
    
    case "$platform" in
        Linux|Darwin)
            echo "🚀 Installing Node.js on Unix/Linux/macOS..."
            
            echo "📥 Downloading and installing nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
            
            echo "🔄 Loading nvm environment..."
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
            
            echo "📦 Downloading and installing Node.js v22..."
            nvm install 22 || { echo "Error: nvm install failed."; exit 1; }
            nvm use 22 || { echo "Error: nvm use failed."; exit 1; }
            
            echo -n "✅ Node.js installation completed! Version: "
            node -v
            echo -n "✅ Current nvm version: "
            nvm current
            echo -n "✅ npm version: "
            npm -v
            ;;
        *)
            echo "Unsupported platform: $platform"
            exit 1
            ;;
    esac
}

# Check if Node.js is already installed and version is >= 18
if command -v node >/dev/null 2>&1; then
    current_version=$(node -v | sed 's/v//')
    major_version=$(echo $current_version | cut -d. -f1)
    
    if [ "$major_version" -ge 18 ]; then
        echo "Node.js is already installed: v$current_version"
    else
        echo "Node.js v$current_version is installed but version < 18. Upgrading..."
        install_nodejs
    fi
else
    echo "Node.js not found. Installing..."
    install_nodejs
fi

# --- 2. Claude Code 安装 (保持不变) ---
if command -v claude >/dev/null 2>&1; then
    echo "Claude Code is already installed: $(claude --version)"
else
    echo "Claude Code not found. Installing..."
    npm install -g @anthropic-ai/claude-code || { echo "Error: Claude Code installation failed."; exit 1; }
fi

# --- 3. 配置 Claude Code 跳过引导 (增加fs和path模块的引入) ---
echo "Configuring Claude Code to skip onboarding..."
node -e '
    const os = require("os");
    const fs = require("fs");
    const path = require("path");
    const homeDir = os.homedir(); 
    const filePath = path.join(homeDir, ".claude.json");
    if (fs.existsSync(filePath)) {
        const content = JSON.parse(fs.readFileSync(filePath, "utf-8"));
        fs.writeFileSync(filePath, JSON.stringify({ ...content, hasCompletedOnboarding: true }, null, 2), "utf-8");
    } else {
        fs.writeFileSync(filePath, JSON.stringify({ hasCompletedOnboarding: true }), "utf-8");
    }
' || { echo "Error: Claude Code onboarding configuration failed."; exit 1; }


# --- 4. 提示用户输入火山引擎 API Key 和选择模型 ---
echo ""
echo "🔑 请输入您的火山引擎 API key:"
echo "   您可以在火山引擎控制台获取 API key。"
echo "   注意: 输入将被隐藏以确保安全。请直接粘贴您的 API key。"
echo ""
read -s volcengine_api_key
echo ""

if [ -z "$volcengine_api_key" ]; then
    echo "⚠️  API key 不能为空。请重新运行脚本。"
    exit 1
fi

echo "请选择您希望使用的火山引擎模型 (例如: dounao-lite-4k, dounao-pro-128k, deepseek-v3-250324):"
read -p "模型名称: " volcengine_model_name

if [ -z "$volcengine_model_name" ]; then
    echo "⚠️  模型名称不能为空。将使用默认模型 'kimi-k2-250711'。"
    volcengine_model_name="kimi-k2-250711"
fi

# --- 5. 配置 Claude Code 直接连接火山引擎 ---
current_shell=$(basename "$SHELL")
case "$current_shell" in
    bash)
        rc_file="$HOME/.bashrc"
        ;;
    zsh)
        rc_file="$HOME/.zshrc"
        ;;
    fish)
        rc_file="$HOME/.config/fish/config.fish"
        ;;
    *)
        rc_file="$HOME/.profile"
        ;;
esac

echo ""
echo "📝 Adding environment variables for direct 火山引擎 connection to $rc_file..."

# 检查变量是否已存在以避免重复
if [ -f "$rc_file" ] && grep -q "ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/v3" "$rc_file"; then
    echo "⚠️  火山引擎配置已存在 in $rc_file. 正在更新..."
    # 移除旧的配置
    sed -i '/export ANTHROPIC_BASE_URL=/d' "$rc_file" 2>/dev/null || true
    sed -i '/export ANTHROPIC_API_KEY=/d' "$rc_file" 2>/dev/null || true
fi

# 追加新的直接连接配置
echo "" >> "$rc_file"
echo "# Claude Code 火山引擎环境变量" >> "$rc_file"
echo "export ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/v3" >> "$rc_file"
echo "export ANTHROPIC_API_KEY=$volcengine_api_key" >> "$rc_file"
echo "export ANTHROPIC_MODEL=$volcengine_model_name" >> "$rc_file"
echo "✅ 火山引擎环境变量已添加到 $rc_file"

echo ""
echo "🎉 Installation and configuration completed successfully!"
echo ""
echo "🔄 Important: Please restart your terminal or run:"
echo "   source $rc_file"
echo ""
echo "🚀 Then you can start using Claude Code directly:"
echo "   claude"
echo ""
echo "💡 Note: Claude Code will now connect directly to 火山引擎 using your provided API key"


