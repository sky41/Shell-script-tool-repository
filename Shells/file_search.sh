#!/bin/bash

# file_search.sh - 文件搜索脚本
# 版本：v1.0.0
# 功能：1. 初步搜索Linux下与关键词相近的文件/文件夹
#       2. 二次精细化查询匹配度更高的结果
#       3. 支持多种文件类型的匹配
#       4. 提供友好的命令行界面

# 版本信息
VERSION="v1.0.0"

# 脚本名称
SCRIPT_NAME=$(basename "$0")

# 默认参数
DEFAULT_DEPTH=3
DEFAULT_MATCH_MODE="fuzzy"

# 颜色定义（默认启用）
USE_COLOR=true

# 检测终端是否支持颜色
if ! [ -t 1 ]; then
    USE_COLOR=false
fi

# 颜色定义
if $USE_COLOR; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    # 不使用颜色
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 帮助信息
show_help() {
    echo -e "${BLUE}文件搜索脚本 ${VERSION}${NC}"
    echo -e ""
    echo -e "${GREEN}用法:${NC} $SCRIPT_NAME [选项]"
    echo -e ""
    echo -e "${GREEN}选项:${NC}"
    echo -e "  -k, --keyword          搜索关键词"
    echo -e "  -e, --extension        文件扩展名（多个扩展名用逗号分隔，如 .log,.c,.txt）"
    echo -e "  -d, --depth            搜索深度（默认: $DEFAULT_DEPTH）"
    echo -e "  -m, --match            匹配模式（exact: 精确匹配, fuzzy: 模糊匹配，默认: $DEFAULT_MATCH_MODE）"
    echo -e "  -c, --content          启用文件内容搜索"
    echo -e "  -C, --content-keyword  内容搜索关键词"
    echo -e "  -h, --help             显示帮助信息"
    echo -e "  -v, --version          显示版本信息"
    echo -e ""
    echo -e "${GREEN}示例:${NC}"
    echo -e "  $SCRIPT_NAME -k error -e .log,.txt"
    echo -e "  $SCRIPT_NAME -k test -d 5 -m exact"
    echo -e "  $SCRIPT_NAME -k log -c -C error -e .log"
    echo -e ""
    echo -e "${GREEN}交互式模式:${NC}"
    echo -e "  直接运行 $SCRIPT_NAME 进入交互式模式"
}

# 显示版本信息
show_version() {
    echo -e "${BLUE}文件搜索脚本 ${VERSION}${NC}"
    echo -e "作者: Shell Script Developer"
    echo -e "日期: $(date +%Y-%m-%d)"
}

# 计算匹配度
calculate_match_score() {
    local file="$1"
    local keyword="$2"
    local extensions="$3"
    local score=0
    
    # 文件名中关键词出现次数
    local name_match=$(echo "$file" | grep -o "$keyword" | wc -l)
    score=$((score + name_match * 10))
    
    # 关键词在文件名中的位置（越靠前分数越高）
    local position=$(echo "$file" | grep -n "$keyword" | head -1 | cut -d: -f1)
    if [ -n "$position" ]; then
        score=$((score + (20 - position) * 2))
    fi
    
    # 文件类型匹配加分
    local ext="${file##*.}"
    if [[ "$extensions" == *"$ext"* ]]; then
        score=$((score + 15))
    fi
    
    echo $score
}

# 初步搜索
initial_search() {
    local keyword="$1"
    local depth="$2"
    local extensions="$3"
    
    echo -e "${YELLOW}正在进行初步搜索...${NC}" >&2
    
    # 构建find命令（使用括号确保正确的优先级）
    local find_cmd="find / \( -type f -o -type d \)"
    
    # 添加深度限制
    if [ "$depth" -gt 0 ]; then
        find_cmd="$find_cmd -maxdepth $depth"
    fi
    
    # 执行搜索
    local results=$(eval "$find_cmd" 2>/dev/null | grep -i "$keyword")
    
    # 处理扩展名过滤
    if [ -n "$extensions" ]; then
        local ext_pattern=$(echo "$extensions" | sed 's/,/\\|/g')
        results=$(echo "$results" | grep -E "\.($ext_pattern)$")
    fi
    
    echo "$results"
}

# 二次精细化搜索
refined_search() {
    local initial_results="$1"
    local keyword="$2"
    local match_mode="$3"
    local extensions="$4"
    
    echo -e "${YELLOW}正在进行精细化搜索...${NC}" >&2
    
    # 计算每个结果的匹配度
    local scored_results=()
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            if [ "$match_mode" == "exact" ]; then
                # 精确匹配
                if echo "$line" | grep -q "^.*$keyword.*$"; then
                    local score=$(calculate_match_score "$line" "$keyword" "$extensions")
                    scored_results+=("$score:$line")
                fi
            else
                # 模糊匹配
                local score=$(calculate_match_score "$line" "$keyword" "$extensions")
                if [ "$score" -gt 0 ]; then
                    scored_results+=("$score:$line")
                fi
            fi
        fi
    done <<< "$initial_results"
    
    # 按匹配度排序
    if [ ${#scored_results[@]} -gt 0 ]; then
        IFS=$'\n' sorted_results=($(sort -nr <<< "${scored_results[*]}"))
        unset IFS
        
        # 提取排序后的结果
        local final_results=()
        for result in "${sorted_results[@]}"; do
            final_results+=("${result#*:}")
        done
        
        # 输出结果，每个结果占一行
        printf "%s\n" "${final_results[@]}"
    else
        echo ""
    fi
}

# 搜索文件内容
search_file_content() {
    local file_path="$1"
    local content_keyword="$2"
    
    echo -e "${YELLOW}正在搜索文件内容...${NC}" >&2
    
    # 检查是否为文件或目录
    if [ -f "$file_path" ]; then
        # 搜索单个文件
        local matches=$(grep -n "$content_keyword" "$file_path" 2>/dev/null)
        if [ -n "$matches" ]; then
            echo -e "${GREEN}文件:${NC} $file_path"
            echo -e "${YELLOW}---------------------------------------------${NC}"
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # 高亮显示关键词
                    if $USE_COLOR; then
                        local highlighted=$(echo "$line" | sed -E "s/($content_keyword)/${RED}\1${NC}/gI")
                    else
                        local highlighted="$line"
                    fi
                    echo -e "$highlighted"
                fi
            done <<< "$matches"
            echo -e "${YELLOW}---------------------------------------------${NC}"
            echo -e ""
        fi
    elif [ -d "$file_path" ]; then
        # 递归搜索目录
        local files=$(find "$file_path" -type f 2>/dev/null)
        local match_count=0
        
        while IFS= read -r file; do
            local matches=$(grep -n "$content_keyword" "$file" 2>/dev/null)
            if [ -n "$matches" ]; then
                echo -e "${GREEN}文件:${NC} $file"
                echo -e "${YELLOW}---------------------------------------------${NC}"
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        # 高亮显示关键词
                        if $USE_COLOR; then
                            local highlighted=$(echo "$line" | sed -E "s/($content_keyword)/${RED}\1${NC}/gI")
                        else
                            local highlighted="$line"
                        fi
                        echo -e "$highlighted"
                    fi
                done <<< "$matches"
                echo -e "${YELLOW}---------------------------------------------${NC}"
                echo -e ""
                match_count=$((match_count + 1))
            fi
        done <<< "$files"
        
        if [ $match_count -eq 0 ]; then
            echo -e "${RED}在目录 '$file_path' 中未找到包含 '$content_keyword' 的文件${NC}"
        else
            echo -e "${GREEN}在目录 '$file_path' 中找到 $match_count 个包含 '$content_keyword' 的文件${NC}"
        fi
    else
        echo -e "${RED}路径 '$file_path' 不存在或无法访问${NC}"
    fi
}

# 显示搜索结果
show_results() {
    local results="$1"
    local keyword="$2"
    
    if [ -z "$results" ]; then
        echo -e "${RED}未找到与 '$keyword' 相关的文件或文件夹${NC}"
        return
    fi
    
    echo -e "${GREEN}搜索结果 (按匹配度排序):${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    
    local count=1
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 高亮显示关键词
            if $USE_COLOR; then
                local highlighted=$(echo "$line" | sed -E "s/($keyword)/${RED}\1${NC}/gI")
            else
                local highlighted="$line"
            fi
            
            # 显示文件详细信息
            echo -e "${GREEN}$count.${NC} $highlighted"
            
            # 检查是否为文件或目录
            if [ -f "$line" ]; then
                # 文件信息
                local file_size=$(ls -lh "$line" | awk '{print $5}')
                local file_type=$(file -b "$line" | cut -d, -f1)
                local mod_time=$(stat -c "%y" "$line" 2>/dev/null || echo "N/A")
                echo -e "   ${BLUE}类型:${NC} 文件"
                echo -e "   ${BLUE}大小:${NC} $file_size"
                echo -e "   ${BLUE}类型描述:${NC} $file_type"
                echo -e "   ${BLUE}修改时间:${NC} $mod_time"
            elif [ -d "$line" ]; then
                # 目录信息
                local dir_size=$(du -sh "$line" 2>/dev/null | awk '{print $1}')
                local file_count=$(ls -la "$line" 2>/dev/null | wc -l)
                local mod_time=$(stat -c "%y" "$line" 2>/dev/null || echo "N/A")
                echo -e "   ${BLUE}类型:${NC} 目录"
                echo -e "   ${BLUE}大小:${NC} $dir_size"
                echo -e "   ${BLUE}文件数量:${NC} $file_count"
                echo -e "   ${BLUE}修改时间:${NC} $mod_time"
            fi
            
            echo -e ""
            count=$((count + 1))
        fi
    done <<< "$results"
    
    echo -e "${YELLOW}=================================================${NC}"
    echo -e "${GREEN}共找到 $(echo "$results" | wc -l) 个结果${NC}"
}

# 交互式菜单
interactive_menu() {
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}        文件搜索工具 ${VERSION}${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo -e ""
    echo -e "${GREEN}功能选择:${NC}"
    echo -e "1. 搜索文件/文件夹"
    echo -e "2. 搜索文件内容"
    echo -e ""
    
    # 获取功能选择
    read -p "请选择功能 (1/2): " function_choice
    if [ -z "$function_choice" ]; then
        function_choice=1
    fi
    
    # 获取用户输入
    read -p "请输入搜索关键词: " keyword
    if [ -z "$keyword" ]; then
        echo -e "${RED}关键词不能为空${NC}"
        return 1
    fi
    
    local content_keyword=""
    if [ "$function_choice" == "2" ]; then
        read -p "请输入内容搜索关键词: " content_keyword
        if [ -z "$content_keyword" ]; then
            echo -e "${RED}内容搜索关键词不能为空${NC}"
            return 1
        fi
    fi
    
    read -p "请输入文件扩展名（多个用逗号分隔，如 .log,.c,.txt，回车跳过）: " extensions
    
    read -p "请输入搜索深度（默认: $DEFAULT_DEPTH，回车使用默认值）: " depth
    if [ -z "$depth" ]; then
        depth=$DEFAULT_DEPTH
    fi
    
    read -p "请输入匹配模式（exact: 精确匹配, fuzzy: 模糊匹配，默认: $DEFAULT_MATCH_MODE）: " match_mode
    if [ -z "$match_mode" ]; then
        match_mode=$DEFAULT_MATCH_MODE
    fi
    
    echo -e ""
    
    # 执行搜索
    perform_search "$keyword" "$extensions" "$depth" "$match_mode" "$function_choice" "$content_keyword"
    
    # 询问是否继续
    echo -e ""
    read -p "是否继续搜索？ (y/n): " continue
    if [[ "$continue" == [Yy]* ]]; then
        interactive_menu
    else
        echo -e "${GREEN}感谢使用文件搜索工具！${NC}"
    fi
}

# 执行搜索
perform_search() {
    local keyword="$1"
    local extensions="$2"
    local depth="$3"
    local match_mode="$4"
    local function_choice="${5:-1}"
    local content_keyword="${6:-}"
    
    echo -e "${YELLOW}搜索参数:${NC}"
    echo -e "  关键词: $keyword"
    echo -e "  扩展名: ${extensions:-无}"
    echo -e "  搜索深度: $depth"
    echo -e "  匹配模式: $match_mode"
    if [ "$function_choice" == "2" ]; then
        echo -e "  功能: 文件内容搜索"
        echo -e "  内容搜索关键词: $content_keyword"
    else
        echo -e "  功能: 文件/文件夹搜索"
    fi
    echo -e ""
    
    # 初步搜索
    local initial_results=$(initial_search "$keyword" "$depth" "$extensions")
    
    # 二次精细化搜索
    local refined_results=$(refined_search "$initial_results" "$keyword" "$match_mode" "$extensions")
    
    # 显示结果
    show_results "$refined_results" "$keyword"
    
    # 如果是内容搜索，对每个结果执行内容搜索
    if [ "$function_choice" == "2" ] && [ -n "$content_keyword" ]; then
        echo -e "${GREEN}开始搜索文件内容...${NC}"
        echo -e "${YELLOW}=================================================${NC}"
        
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                search_file_content "$line" "$content_keyword"
            fi
        done <<< "$refined_results"
        
        echo -e "${YELLOW}=================================================${NC}"
    fi
}

# 主函数
main() {
    # 解析命令行参数
    local function_choice=1
    local content_keyword=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--keyword)
                keyword="$2"
                shift 2
                ;;
            -e|--extension)
                extensions="$2"
                shift 2
                ;;
            -d|--depth)
                depth="$2"
                shift 2
                ;;
            -m|--match)
                match_mode="$2"
                shift 2
                ;;
            -c|--content)
                function_choice=2
                shift 1
                ;;
            -C|--content-keyword)
                content_keyword="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有提供关键词，进入交互式模式
    if [ -z "$keyword" ]; then
        interactive_menu
    else
        # 检查内容搜索是否提供了关键词
        if [ "$function_choice" == "2" ] && [ -z "$content_keyword" ]; then
            echo -e "${RED}使用内容搜索时，必须提供内容搜索关键词 (-C, --content-keyword)${NC}"
            show_help
            exit 1
        fi
        
        # 使用命令行参数执行搜索
        # 设置默认值
        if [ -z "$depth" ]; then
            depth=$DEFAULT_DEPTH
        fi
        if [ -z "$match_mode" ]; then
            match_mode=$DEFAULT_MATCH_MODE
        fi
        
        perform_search "$keyword" "$extensions" "$depth" "$match_mode" "$function_choice" "$content_keyword"
    fi
}

# 执行主函数
main "$@"
