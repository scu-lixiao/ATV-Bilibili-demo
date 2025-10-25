#!/bin/bash

# tvOS 26 主题实施验证脚本
# 检查所有新增文件和修改

echo "🔍 验证 tvOS 26 Liquid Glass 主题实施..."
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 计数器
TOTAL=0
PASSED=0
FAILED=0

# 检查函数
check_file() {
    local file=$1
    local desc=$2
    TOTAL=$((TOTAL + 1))

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $desc"
        echo -e "   📄 $file"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $desc"
        echo -e "   ❌ 文件不存在: $file"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

echo "=== 新增文件检查 ==="
echo ""

check_file "BilibiliLive/Extensions/ColorPalette.swift" "色彩系统 (ColorPalette)"
check_file "BilibiliLive/Extensions/ThemeManager.swift" "主题管理器 (ThemeManager)"
check_file "BilibiliLive/Component/View/LiquidGlassMaterial.swift" "Liquid Glass 材质 (LiquidGlassMaterial)"
check_file "BilibiliLive/Component/View/GradientBackgroundView.swift" "渐变背景 (GradientBackgroundView)"
check_file "THEME_IMPLEMENTATION.md" "实施文档"

echo "=== 修改文件检查 ==="
echo ""

check_file "BilibiliLive/AppDelegate.swift" "全局主题配置 (AppDelegate)"
check_file "BilibiliLive/BLTabBarViewController.swift" "Tab Bar 改造"
check_file "BilibiliLive/Module/Personal/SettingsViewController.swift" "设置视图改造"
check_file "BilibiliLive/Component/Feed/FeedCollectionViewCell.swift" "Feed 卡片焦点效果"

echo ""
echo "=== 代码内容验证 ==="
echo ""

# 检查关键代码片段
echo "检查 ThemeManager.shared..."
if grep -q "ThemeManager.shared" BilibiliLive/AppDelegate.swift 2>/dev/null; then
    echo -e "${GREEN}✓${NC} AppDelegate 使用了 ThemeManager"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} AppDelegate 未使用 ThemeManager"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
echo ""

echo "检查 Liquid Glass 效果..."
if grep -q "UIGlassEffect" BilibiliLive/Extensions/ThemeManager.swift 2>/dev/null; then
    echo -e "${GREEN}✓${NC} ThemeManager 实现了 UIGlassEffect"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} ThemeManager 未实现 UIGlassEffect"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
echo ""

echo "检查焦点动画..."
if grep -q "applyFocusedStyle" BilibiliLive/Component/Feed/FeedCollectionViewCell.swift 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Feed Cell 实现了焦点效果"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} Feed Cell 未实现焦点效果"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
echo ""

echo "检查色彩定义..."
if grep -q "ColorPalette.background" BilibiliLive/Extensions/ColorPalette.swift 2>/dev/null; then
    echo -e "${GREEN}✓${NC} ColorPalette 定义了色彩系统"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} ColorPalette 未定义色彩系统"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))
echo ""

echo "=== 验证结果 ==="
echo ""
echo "总计: $TOTAL 项"
echo -e "${GREEN}通过: $PASSED 项${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}失败: $FAILED 项${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  部分检查未通过,请检查上述错误${NC}"
    exit 1
else
    echo -e "${GREEN}失败: 0 项${NC}"
    echo ""
    echo -e "${GREEN}🎉 所有检查通过!tvOS 26 主题实施完成!${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 使用 Xcode 打开项目"
    echo "  2. 选择 Apple TV 模拟器 (tvOS 26)"
    echo "  3. 构建并运行项目"
    echo "  4. 验证 Liquid Glass 效果和焦点动画"
    exit 0
fi
