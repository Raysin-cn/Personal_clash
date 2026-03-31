#!/bin/bash

# Clash 代理节点切换脚本
# 使用 Clash RESTful API 进行代理节点切换

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 配置信息
CLASH_API="http://127.0.0.1:9091"
SECRET=""

# 尝试从不同位置读取 secret
if [ -f "conf/config.yaml" ]; then
    SECRET=$(grep "^secret:" conf/config.yaml | awk '{print $2}' | tr -d "'\"")
fi

# 如果 secret 为空，尝试从环境变量读取
if [ -z "$SECRET" ] && [ -f ".env" ]; then
    source .env
    SECRET="$CLASH_SECRET"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[错误]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1" >&2
}

# 测试 API 连接并确定认证方式
test_api_auth() {
    local test_url="${CLASH_API}/proxies"

    # 方法1: 尝试无认证
    if curl -s -m 3 "$test_url" 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); sys.exit(0 if 'proxies' in data else 1)" 2>/dev/null; then
        AUTH_METHOD="none"
        return 0
    fi

    # 如果 SECRET 为空，无法继续
    if [ -z "$SECRET" ]; then
        return 1
    fi

    # 方法2: 尝试 Bearer token
    if curl -s -m 3 -H "Authorization: Bearer ${SECRET}" "$test_url" 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); sys.exit(0 if 'proxies' in data else 1)" 2>/dev/null; then
        AUTH_METHOD="bearer"
        return 0
    fi

    # 方法3: 尝试直接 token
    if curl -s -m 3 -H "Authorization: ${SECRET}" "$test_url" 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); sys.exit(0 if 'proxies' in data else 1)" 2>/dev/null; then
        AUTH_METHOD="direct"
        return 0
    fi

    # 方法4: 尝试 URL 参数
    if curl -s -m 3 "${test_url}?secret=${SECRET}" 2>/dev/null | python3 -c "import json, sys; data=json.load(sys.stdin); sys.exit(0 if 'proxies' in data else 1)" 2>/dev/null; then
        AUTH_METHOD="param"
        return 0
    fi

    return 1
}

# 根据认证方式执行 curl 请求
api_request() {
    local method="$1"
    local url="$2"
    shift 2

    case "$AUTH_METHOD" in
        "none")
            curl -s -m 10 "$@" "${CLASH_API}${url}"
            ;;
        "bearer")
            curl -s -m 10 -H "Authorization: Bearer ${SECRET}" "$@" "${CLASH_API}${url}"
            ;;
        "direct")
            curl -s -m 10 -H "Authorization: ${SECRET}" "$@" "${CLASH_API}${url}"
            ;;
        "param")
            if [[ "$url" == *"?"* ]]; then
                curl -s -m 10 "$@" "${CLASH_API}${url}&secret=${SECRET}"
            else
                curl -s -m 10 "$@" "${CLASH_API}${url}?secret=${SECRET}"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查 Clash 是否运行
check_clash_running() {
    if ! netstat -tuln | grep ":9091" > /dev/null 2>&1; then
        print_error "Clash API 端口 9091 未监听"
        print_info "请先启动 Clash 或检查端口配置"
        exit 1
    fi

    # 测试 API 连接
    if ! test_api_auth; then
        print_error "无法连接到 Clash API"
        print_warning "可能是认证配置不正确"
        print_info "请检查 conf/config.yaml 中的 secret 配置"
        exit 1
    fi
}

# 获取代理组列表
get_proxy_groups() {
    api_request GET "/proxies" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    groups = data.get('proxies', {})
    for name, info in groups.items():
        if info.get('type') == 'Selector':
            print(name)
except:
    pass
"
}

# URL 编码函数
url_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# 获取指定代理组的节点列表
get_proxy_nodes() {
    local group="$1"
    local encoded_group=$(url_encode "$group")
    api_request GET "/proxies/${encoded_group}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'all' in data:
        for node in data['all']:
            print(node)
except:
    pass
"
}

# 获取当前选中的节点
get_current_node() {
    local group="$1"
    local encoded_group=$(url_encode "$group")
    api_request GET "/proxies/${encoded_group}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'now' in data:
        print(data['now'])
except:
    pass
"
}

# 切换代理节点
switch_proxy() {
    local group="$1"
    local node="$2"
    local encoded_group=$(url_encode "$group")

    response=$(api_request PUT "/proxies/${encoded_group}" \
        -X PUT \
        -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${node}\"}")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# 显示节点延迟
test_node_delay() {
    local group="$1"
    local node="$2"
    local encoded_node=$(url_encode "$node")

    # 通过 API 触发延迟测试
    delay=$(api_request GET "/proxies/${encoded_node}/delay?timeout=5000&url=http://www.gstatic.com/generate_204" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'delay' in data:
        print(str(data['delay']) + 'ms')
    else:
        print('超时')
except:
    print('测试失败')
")

    echo "$delay"
}

# 主菜单
show_menu() {
    clear
    echo "=================================="
    echo "   Clash 代理节点切换工具"
    echo "=================================="
    echo ""
}

# 选择代理组
select_proxy_group() {
    print_info "正在获取代理组列表..."
    echo "" >&2

    # 获取代理组
    mapfile -t groups < <(get_proxy_groups)

    if [ ${#groups[@]} -eq 0 ]; then
        print_error "未找到可用的代理组"
        exit 1
    fi

    # 显示代理组列表
    echo "可用的代理组：" >&2
    echo "" >&2
    for i in "${!groups[@]}"; do
        echo "  $((i+1)). ${groups[$i]}" >&2
    done
    echo "" >&2

    # 用户选择
    while true; do
        read -p "请选择代理组 [1-${#groups[@]}] (输入 q 退出): " choice >&2

        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            print_info "已退出"
            exit 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#groups[@]} ]; then
            selected_group="${groups[$((choice-1))]}"
            break
        else
            print_error "无效的选择，请重新输入"
        fi
    done

    echo "$selected_group"
}

# 选择代理节点
select_proxy_node() {
    local group="$1"

    print_info "正在获取节点列表..."
    echo "" >&2

    # 获取当前节点
    current_node=$(get_current_node "$group")

    # 获取节点列表
    mapfile -t nodes < <(get_proxy_nodes "$group")

    if [ ${#nodes[@]} -eq 0 ]; then
        print_error "未找到可用的节点"
        exit 1
    fi

    # 显示节点列表
    echo "代理组: ${group}" >&2
    echo "当前节点: ${GREEN}${current_node}${NC}" >&2
    echo "" >&2
    echo "可用的节点：" >&2
    echo "" >&2

    for i in "${!nodes[@]}"; do
        if [ "${nodes[$i]}" = "$current_node" ]; then
            echo -e "  $((i+1)). ${GREEN}${nodes[$i]} (当前)${NC}" >&2
        else
            echo "  $((i+1)). ${nodes[$i]}" >&2
        fi
    done
    echo "" >&2

    # 用户选择
    while true; do
        read -p "请选择节点 [1-${#nodes[@]}] (输入 t 测试延迟, 输入 q 退出): " choice >&2

        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            print_info "已退出"
            exit 0
        fi

        if [ "$choice" = "t" ] || [ "$choice" = "T" ]; then
            # 测试所有节点延迟
            echo "" >&2
            print_info "开始测试所有节点延迟 (可能需要一些时间)..."
            echo "" >&2
            for node in "${nodes[@]}"; do
                delay=$(test_node_delay "$group" "$node")
                if [ "$node" = "$current_node" ]; then
                    echo -e "  ${GREEN}${node}${NC}: ${delay}" >&2
                else
                    echo "  ${node}: ${delay}" >&2
                fi
            done
            echo "" >&2
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#nodes[@]} ]; then
            selected_node="${nodes[$((choice-1))]}"
            break
        else
            print_error "无效的选择，请重新输入"
        fi
    done

    echo "$selected_node"
}

# 主程序
main() {
    show_menu

    # 检查 Clash 是否运行并测试 API 连接
    check_clash_running
    print_success "Clash API 连接成功 (认证方式: ${AUTH_METHOD})"
    echo ""

    # 选择代理组
    proxy_group=$(select_proxy_group)
    echo ""

    # 选择代理节点
    proxy_node=$(select_proxy_node "$proxy_group")
    echo ""

    # 确认切换
    current_node=$(get_current_node "$proxy_group")

    if [ "$proxy_node" = "$current_node" ]; then
        print_warning "所选节点已是当前节点，无需切换"
        exit 0
    fi

    print_info "准备切换节点："
    echo "  代理组: ${proxy_group}"
    echo "  原节点: ${current_node}"
    echo "  新节点: ${proxy_node}"
    echo ""

    read -p "确认切换? [Y/n]: " confirm

    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        print_info "已取消切换"
        exit 0
    fi

    # 执行切换
    print_info "正在切换节点..."

    if switch_proxy "$proxy_group" "$proxy_node"; then
        print_success "节点切换成功！"
        echo ""

        # 测试新节点延迟
        delay=$(test_node_delay "$proxy_group" "$proxy_node")
        print_info "新节点延迟: ${delay}"

        # 测试连接
        echo ""
        print_info "正在测试代理连接..."
        export http_proxy="http://127.0.0.1:7893"
        export https_proxy="http://127.0.0.1:7893"

        if curl -s -m 10 https://www.google.com > /dev/null 2>&1; then
            print_success "代理连接测试成功"
        else
            print_warning "代理连接测试失败，请检查节点是否正常"
        fi

        unset http_proxy https_proxy
    else
        print_error "节点切换失败！"
        exit 1
    fi
}

# 运行主程序
main
