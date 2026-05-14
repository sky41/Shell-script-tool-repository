#!/bin/bash
#
# Big_Users - find big disk space users in various directories
# Version: 2.0
# Author: System Administrator
##############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认参数
CHECK_DIRECTORIES="/var/log /home"
TOP_N=10
OUTPUT_FILE=""
SHOW_SCREEN=true
HUMAN_READABLE=true

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -d, --dir DIRECTORIES   指定要检查的目录（空格分隔）"
    echo "  -n, --number N          显示前N个最大文件/目录（默认10）"
    echo "  -o, --output FILE       将报告输出到指定文件"
    echo "  -s, --silent            仅输出到文件，不显示在屏幕上"
    echo "  -b, --bytes             以字节为单位显示大小（默认人类可读格式）"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                        # 使用默认设置检查 /var/log 和 /home"
    echo "  $0 -d \"/var/log /opt\"     # 检查指定目录"
    echo "  $0 -n 20 -o report.txt    # 显示前20个并输出到文件"
    echo "  $0 -s -o disk_usage.rpt   # 静默模式，仅输出到文件"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                CHECK_DIRECTORIES="$2"
                shift 2
                ;;
            -n|--number)
                TOP_N="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -s|--silent)
                SHOW_SCREEN=false
                shift
                ;;
            -b|--bytes)
                HUMAN_READABLE=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 格式化大小（人类可读格式）
format_size() {
    local size="$1"
    if [ "$HUMAN_READABLE" = true ]; then
        if [ "$size" -lt 1024 ]; then
            echo "${size}B"
        elif [ "$size" -lt 1048576 ]; then
            echo "$((size / 1024))KB"
        elif [ "$size" -lt 1073741824 ]; then
            echo "$((size / 1048576))MB"
        else
            echo "$((size / 1073741824))GB"
        fi
    else
        echo "$size"
    fi
}

# 检查目录是否存在
check_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo -e "${RED}错误: 目录 $dir 不存在或无法访问${NC}"
        return 1
    fi
    if [ ! -r "$dir" ]; then
        echo -e "${YELLOW}警告: 没有读取目录 $dir 的权限${NC}"
        return 1
    fi
    return 0
}

# 获取目录大小统计
get_dir_stats() {
    local dir="$1"
    echo -e "\n${BLUE}========== 目录: $dir ==========${NC}"
    
    # 获取目录总大小
    local total_size=$(du -s "$dir" 2>/dev/null | awk '{print $1}')
    echo -e "总大小: ${GREEN}$(format_size $((total_size * 1024)))${NC}"
    
    # 检查是否有足够的权限
    if [ -z "$total_size" ]; then
        echo -e "${YELLOW}无法获取目录大小（权限不足）${NC}"
        return
    fi
    
    # 获取文件数量
    local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
    local dir_count=$(find "$dir" -type d 2>/dev/null | wc -l)
    echo "文件数量: $file_count"
    echo "子目录数量: $((dir_count - 1))"
    
    # 列出TOP N大文件/目录
    echo -e "\n${YELLOW}Top $TOP_N 最大文件/目录:${NC}"
    echo "序号    大小          路径"
    echo "-----------------------------"
    
    if [ "$HUMAN_READABLE" = true ]; then
        du -S "$dir" 2>/dev/null | sort -rn | head -n "$TOP_N" | \
        awk '{print $1, $2}' | while read -r size path; do
            echo -e "$(format_size $((size * 1024)))\t$path"
        done | nl -w2 -s')   '
    else
        du -S "$dir" 2>/dev/null | sort -rn | head -n "$TOP_N" | \
        awk '{print $1 * 1024, $2}' | nl -w2 -s')   '
    fi
}

######################### Main Script #######################

# 解析参数
parse_args "$@"

# 检查是否有输出文件
if [ -n "$OUTPUT_FILE" ]; then
    # 创建输出文件并重定向stdout
    exec > >(tee "$OUTPUT_FILE") 2>&1
elif [ "$SHOW_SCREEN" = false ]; then
    echo "错误: 使用 -s/--silent 选项时必须指定输出文件"
    exit 1
fi

# 检查是否为root用户（可选，但某些目录需要root权限）
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}警告: 建议使用root用户运行以获取完整权限${NC}"
fi

# 获取当前时间
DATE=$(date '+%Y-%m-%d %H:%M:%S')
REPORT_DATE=$(date '+%Y%m%d_%H%M%S')

# 打印报告头部
echo -e "\n${BLUE}===============================================${NC}"
echo -e "${GREEN}磁盘空间使用情况报告${NC}"
echo -e "${BLUE}===============================================${NC}"
echo "生成时间: $DATE"
echo "检查目录: $CHECK_DIRECTORIES"
echo "显示数量: Top $TOP_N"
echo -e "${BLUE}===============================================${NC}"

# 遍历检查每个目录
for DIR_CHECK in $CHECK_DIRECTORIES; do
    if check_directory "$DIR_CHECK"; then
        get_dir_stats "$DIR_CHECK"
    fi
done

# 打印报告尾部
echo -e "\n${BLUE}===============================================${NC}"
echo -e "${GREEN}报告结束${NC}"
echo -e "${BLUE}===============================================${NC}"

if [ -n "$OUTPUT_FILE" ]; then
    echo -e "\n报告已保存至: ${YELLOW}$OUTPUT_FILE${NC}"
fi
