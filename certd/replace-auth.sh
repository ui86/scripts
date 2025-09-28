#!/bin/bash
# replace-auth.sh - CertD 容器授权文件替换工具

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_CONTAINER_NAME="certd"
TARGET_PATH="/app/node_modules/@certd/plus-core/dist/index.js"
DOWNLOAD_URL="https://raw.githubusercontent.com/ui86/scripts/refs/heads/main/certd/index.js"
TEMP_FILE="/tmp/bypass-index.js"

# 函数：检查容器是否存在
check_container_exists() {
    local container_name="$1"
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        return 0
    elif docker ps -a --format "{{.ID}}" | grep -q "^${container_name}"; then
        return 0
    else
        return 1
    fi
}

# 函数：显示可用容器列表
show_available_containers() {
    echo -e "${BLUE}当前系统中的所有容器：${NC}"
    echo "----------------------------------------"
    docker ps -a --format "table {{.Names}}\t{{.ID}}\t{{.Status}}"
    echo "----------------------------------------"
}

# 函数：获取容器名称
get_container_name() {
    local container_name="$DEFAULT_CONTAINER_NAME"
    
    # 检查是否提供了命令行参数
    if [ $# -eq 1 ]; then
        container_name="$1"
    fi
    
    # 检查容器是否存在
    if check_container_exists "$container_name"; then
        # 将状态信息输出到stderr，避免命令替换时被捕获
        echo -e "${GREEN}找到容器: $container_name${NC}" >&2
        echo "$container_name"
        return 0
    fi
    
    # 如果容器不存在，显示提示信息
    echo -e "${YELLOW}警告: 容器 '$container_name' 不存在${NC}"
    show_available_containers
    
    # 循环直到用户输入有效的容器名称
    while true; do
        echo ""
        echo -e "${BLUE}请输入容器名称或容器ID (输入 'q' 退出):${NC}"
        read -p "> " user_input
        
        # 检查用户是否想要退出
        if [ "$user_input" = "q" ] || [ "$user_input" = "Q" ]; then
            echo -e "${YELLOW}操作已取消${NC}"
            exit 0
        fi
        
        # 检查用户输入是否为空
        if [ -z "$user_input" ]; then
            echo -e "${RED}错误: 输入不能为空${NC}"
            continue
        fi
        
        # 检查容器是否存在
        if check_container_exists "$user_input"; then
            # 将状态信息输出到stderr，避免命令替换时被捕获
            echo -e "${GREEN}找到容器: $user_input${NC}" >&2
            echo "$user_input"
            return 0
        else
            echo -e "${RED}错误: 容器 '$user_input' 不存在，请重新输入${NC}"
        fi
    done
}

# 函数：下载文件
download_file() {
    echo -e "${BLUE}正在下载授权文件...${NC}"
    
    # 清理可能存在的旧文件
    rm -f "$TEMP_FILE"
    
    # 尝试使用 curl 下载
    if command -v curl >/dev/null 2>&1; then
        if curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
            echo -e "${GREEN}✓ 使用 curl 下载成功${NC}"
            return 0
        else
            echo -e "${YELLOW}curl 下载失败，尝试使用 wget...${NC}"
        fi
    fi
    
    # 尝试使用 wget 下载
    if command -v wget >/dev/null 2>&1; then
        if wget -O "$TEMP_FILE" "$DOWNLOAD_URL"; then
            echo -e "${GREEN}✓ 使用 wget 下载成功${NC}"
            return 0
        else
            echo -e "${RED}✗ wget 下载也失败${NC}"
        fi
    fi
    
    echo -e "${RED}错误: 下载失败，请检查网络连接${NC}"
    return 1
}

# 函数：验证下载的文件
validate_downloaded_file() {
    if [ ! -f "$TEMP_FILE" ]; then
        echo -e "${RED}错误: 下载的文件不存在${NC}"
        return 1
    fi
    
    if [ ! -s "$TEMP_FILE" ]; then
        echo -e "${RED}错误: 下载的文件为空${NC}"
        return 1
    fi
    
    # 检查文件是否是 JavaScript 文件
    if ! head -n 5 "$TEMP_FILE" | grep -q -E "(function|const|var|let|module|require)" 2>/dev/null; then
        echo -e "${YELLOW}警告: 下载的文件可能不是有效的 JavaScript 文件${NC}"
        echo -e "${BLUE}文件前几行内容:${NC}"
        head -n 3 "$TEMP_FILE"
        echo ""
        echo -e "${BLUE}是否继续? (y/N):${NC}"
        read -p "> " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ 文件验证通过${NC}"
    return 0
}

# 函数：清理临时文件
cleanup() {
    if [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
        echo -e "${BLUE}✓ 临时文件已清理${NC}"
    fi
}

# 主程序开始
echo -e "${BLUE}=== CertD 容器授权文件替换工具 ===${NC}"
echo ""

# 检查一下docker是否存在
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}错误: 未安装docker，请先安装docker${NC}"
    exit 1
fi

# 获取容器名称
CONTAINER_NAME=$(get_container_name "$@")

echo ""
echo -e "${BLUE}目标容器: ${GREEN}$CONTAINER_NAME${NC}"
echo -e "${BLUE}目标路径: ${GREEN}$TARGET_PATH${NC}"
echo ""

# 检查容器状态
container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
if [ "$container_status" = "running" ]; then
    echo -e "${GREEN}容器状态: 运行中${NC}"
elif [ "$container_status" = "exited" ]; then
    echo -e "${YELLOW}容器状态: 已停止${NC}"
else
    echo -e "${RED}无法获取容器状态${NC}"
fi

# 下载文件
if ! download_file; then
    echo -e "${RED}下载失败，操作终止${NC}"
    exit 1
fi

# 验证下载的文件
if ! validate_downloaded_file; then
    echo -e "${RED}文件验证失败，操作终止${NC}"
    cleanup
    exit 1
fi

# 复制文件到容器
echo -e "${BLUE}正在复制文件到容器...${NC}"
if docker cp "$TEMP_FILE" "$CONTAINER_NAME:$TARGET_PATH"; then
    echo -e "${GREEN}✓ 文件已成功复制到容器${NC}"
    
    # 重启容器
    echo -e "${BLUE}正在重启容器 $CONTAINER_NAME...${NC}"
    if docker restart "$CONTAINER_NAME"; then
        echo -e "${GREEN}✓ 容器已成功重启${NC}"
        echo ""
        echo -e "${GREEN}=== 授权文件替换完成！===${NC}"
        echo -e "${BLUE}提示: 可以使用以下命令查看容器日志:${NC}"
        echo -e "${YELLOW}docker logs -f $CONTAINER_NAME${NC}"
    else
        echo -e "${RED}✗ 重启容器失败${NC}"
        cleanup
        exit 1
    fi
else
    echo -e "${RED}✗ 复制文件到容器失败${NC}"
    echo -e "${YELLOW}可能的原因:${NC}"
    echo -e "${YELLOW}1. 容器不存在或无法访问${NC}"
    echo -e "${YELLOW}2. 目标路径不存在${NC}"
    echo -e "${YELLOW}3. 权限不足${NC}"
    cleanup
    exit 1
fi

# 清理临时文件
cleanup

echo -e "${GREEN}操作完成！${NC}"
