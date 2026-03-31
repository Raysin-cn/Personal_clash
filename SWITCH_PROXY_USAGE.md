# Clash 代理节点切换工具使用说明

## 脚本列表

- `start_clash.sh` - 启动 Clash 服务（会自动停止旧进程）
- `stop_clash.sh` - 停止 Clash 服务
- `restart_clash.sh` - 重启 Clash 服务
- `switch_proxy.sh` - **交互式切换代理节点**
- `check_clash_proxy.sh` - 检查 Clash 代理状态

## 使用 switch_proxy.sh 切换节点

### 基本使用

```bash
./switch_proxy.sh
```

### 操作步骤

1. **选择代理组**
   - 输入代理组编号（如 11 = 🔰 节点选择）
   - 输入 `q` 退出

2. **选择节点**
   - 输入节点编号切换到该节点
   - 输入 `t` 测试所有节点延迟
   - 输入 `q` 退出
   - 当前使用的节点会以绿色显示

3. **确认切换**
   - 输入 `y` 确认切换
   - 输入 `n` 取消

4. **自动验证**
   - 脚本会自动测试新节点的延迟
   - 自动验证代理连接是否正常

## 常见问题

### 问题1: 换订阅后脚本报错 "无法连接到 Clash API"

**原因**: 换订阅链接后重新启动 Clash 时，旧进程没有完全停止，导致新进程无法启动。

**解决方法**:

```bash
# 方法1: 使用改进后的停止脚本
./stop_clash.sh
./start_clash.sh

# 方法2: 使用重启脚本
./restart_clash.sh

# 方法3: 手动停止进程后重启
pkill -f clash-linux-amd64
./start_clash.sh
```

### 问题2: 脚本提示 "端口已被占用"

**原因**: 有其他用户的 Clash 实例占用了相同端口。

**解决方法**:

1. 检查是否有多个 Clash 进程运行:
```bash
ps aux | grep clash-linux-amd64
```

2. 停止自己的进程:
```bash
./stop_clash.sh
```

3. 重新启动:
```bash
./start_clash.sh
```

### 问题3: 测试延迟时显示 "超时"

**原因**: 节点可能暂时不可用或响应慢。

**说明**: 这是正常现象，可以选择其他延迟较低的节点。

## 配置信息

- **API 端口**: 9091（避免与其他用户冲突）
- **代理端口**: 7890 (HTTP)
- **SOCKS5 端口**: 7891
- **配置文件**: `conf/config.yaml`
- **日志文件**: `logs/clash.log`

## 端口说明

每个用户的 Clash 实例使用独立的 API 端口:
- **9091** - 你的 API 端口
- **9090** - 可能被其他用户占用

如果需要修改端口，编辑:
1. `temp/templete_config.yaml` 中的 `external-controller`
2. `switch_proxy.sh` 中的 `CLASH_API` 变量
3. 重新启动 Clash

## 工作原理

1. `switch_proxy.sh` 通过 Clash RESTful API 进行操作
2. 使用 `conf/config.yaml` 中的 `secret` 进行认证
3. 每次运行时自动读取最新的 `secret`
4. 支持多种认证方式（Bearer Token、直接 Token、URL 参数）

## 技巧

### 快速切换到特定节点

可以使用管道输入自动化操作:

```bash
# 切换到代理组11的节点2
echo -e "11\n2\ny" | ./switch_proxy.sh

# 测试代理组11的所有节点延迟
echo -e "11\nt\nq" | ./switch_proxy.sh
```

### 查看当前使用的节点

```bash
./check_clash_proxy.sh
```

### 开启/关闭系统代理

```bash
# 开启代理
source clash.sh
proxy_on

# 关闭代理
proxy_off
```

## 维护

### 更新订阅

1. 修改 `.env` 文件中的 `CLASH_URL`
2. 运行 `./start_clash.sh`（会自动停止旧进程）
3. 使用 `./switch_proxy.sh` 选择节点

### 查看日志

```bash
tail -f logs/clash.log
```

### 清理缓存

```bash
rm -f conf/cache.db
./restart_clash.sh
```

## 注意事项

1. ⚠️ 每次换订阅链接后，必须先停止旧 Clash 进程再启动新的
2. ⚠️ `secret` 会在每次启动时重新生成，这是正常的
3. ⚠️ 不要同时运行多个 Clash 实例（会导致端口冲突）
4. ✅ 推荐使用 `./start_clash.sh`（已包含自动停止旧进程的逻辑）
