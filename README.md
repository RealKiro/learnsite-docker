# LearnSite Docker 部署方案

本项目提供 LearnSite 学习平台的 Docker 容器化部署方案，支持一键部署、完整部署以及数据库和应用的分别部署。

## 📋 目录

- [快速开始](#快速开始)
- [部署方式](#部署方式)
  - [一键部署脚本（推荐）](#一键部署脚本推荐)
  - [完整部署（LearnSite + MSSQL）](#完整部署learnsite--mssql)
  - [仅部署 MSSQL 数据库](#仅部署-mssql-数据库)
  - [仅部署 LearnSite 应用](#仅部署-learnsite-应用)
- [环境变量说明](#环境变量说明)
- [使用指南](#使用指南)
- [常见问题](#常见问题)

---

## 快速开始

### 🚀 一行命令快速部署（Linux）

```bash
# 快速部署（使用默认配置）
bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) --quick
```

---

## 部署方式

### 一键部署脚本（推荐）

脚本支持交互式和命令行参数两种方式，适用于 Linux 环境。

#### 使用方式

```bash
# 方式一：交互式部署（推荐新手）
bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh)

# 方式二：快速部署（默认配置）
bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) --quick

# 方式三：自定义部署
bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) -p MySecret123 -w 80 -d 1433

# 查看帮助
bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) --help
```

#### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-q, --quick` | 快速模式，无需交互 | - |
| `-p, --password` | 指定数据库密码 | `YourStrong@Passw0rd123` |
| `-w, --web-port` | 指定Web服务端口 | `8080` |
| `-d, --db-port` | 指定数据库端口 | `1433` |
| `-h, --help` | 显示帮助信息 | - |

#### 脚本功能

- 自动获取 root 权限
- 自动创建目录结构 `/docker/learnsite/{app, data}`
- 自动下载最新配置文件
- 支持自定义密码和端口
- 自动完成 Docker Compose 部署
- 兼容重复运行（已存在的资源自动跳过）

---

### 完整部署（LearnSite + MSSQL）

使用 `docker-compose.yml` 一键部署 LearnSite 应用和 MSSQL 数据库。

#### 部署步骤

1. **克隆或下载配置文件**
   ```bash
   git clone https://gitee.com/realiy/learnsite-docker.git
   cd learnsite-docker
   ```

2. **修改配置（可选）**
   
   编辑 `docker-compose.yml`，主要修改：
   - `MSSQL_SA_PASSWORD`：数据库密码
   - `DB_PASSWORD`：应用连接数据库的密码（必须与上面一致）
   - 端口映射（如需修改）

3. **启动服务**
   ```bash
   docker compose -f docker-compose.yml up -d
   ```

4. **查看状态**
   ```bash
   docker compose -f docker-compose.yml ps
   ```

5. **查看日志**
   ```bash
   docker compose -f docker-compose.yml logs -f
   ```

6. **停止服务**
   ```bash
   docker compose -f docker-compose.yml down
   ```

#### 访问地址

- LearnSite：http://localhost:8080

---

### 仅部署 MSSQL 数据库

使用 `docker-compose.mssql.yml` 单独部署 MSSQL 数据库。

#### 适用场景

- 已有外部数据库，仅需本地数据库
- 需要将数据库与应用分开部署
- 多个应用共享同一个数据库

#### 部署步骤

1. **下载配置文件**
   ```bash
   wget https://gitee.com/realiy/learnsite-docker/raw/main/docker-compose.mssql.yml
   ```

2. **修改配置**
   
   编辑 `docker-compose.mssql.yml`：
   - `MSSQL_SA_PASSWORD`：设置数据库密码
   - 网络模式：host 或 bridge（根据需要选择）
   - 端口映射（bridge 模式下需要）

3. **启动数据库**
   ```bash
   docker compose -f docker-compose.mssql.yml up -d
   ```

4. **验证数据库**
   ```bash
   docker compose -f docker-compose.mssql.yml ps
   ```

#### 健康检查

数据库容器内置健康检查，确保数据库正常运行后才标记为就绪。

---

### 仅部署 LearnSite 应用

使用 `docker-compose.learnsite.yml` 单独部署 LearnSite 应用，连接外部数据库。

#### 适用场景

- 使用外部云数据库
- 数据库已单独部署
- 需要频繁更新应用而不影响数据库

#### 部署步骤

1. **下载配置文件**
   ```bash
   wget https://gitee.com/realiy/learnsite-docker/raw/main/docker-compose.learnsite.yml
   ```

2. **修改数据库连接配置**
   
   编辑 `docker-compose.learnsite.yml`：
   - `DB_HOST`：数据库主机地址（默认 `host.docker.internal` 可访问宿主机）
   - `DB_NAME`：数据库名称
   - `DB_USER`：数据库用户名
   - `DB_PASSWORD`：数据库密码（必须与数据库实际密码一致）
   - 其他环境变量根据需要调整

3. **启动应用**
   ```bash
   docker compose -f docker-compose.learnsite.yml up -d
   ```

4. **查看应用状态**
   ```bash
   docker compose -f docker-compose.learnsite.yml ps
   ```

---

## 环境变量说明

### LearnSite 应用环境变量

| 变量名 | 说明 | 默认值 | 是否必填 |
|--------|------|--------|----------|
| `DB_HOST` | 数据库主机地址 | - | 是 |
| `DB_NAME` | 数据库名称 | `learnsite` | 是 |
| `DB_USER` | 数据库用户名 | `sa` | 是 |
| `DB_PASSWORD` | 数据库密码 | - | 是 |
| `AUTO_UPDATE_SOURCE` | 是否自动更新源码 | `false` | 否 |
| `PRIMARY_REPO_URL` | 主源码仓库地址 | - | 否 |
| `FALLBACK_REPO_URL` | 备用源码仓库地址 | - | 否 |
| `BRANCH` | 源码分支 | `master` | 否 |

### MSSQL 数据库环境变量

| 变量名 | 说明 | 默认值 | 是否必填 |
|--------|------|--------|----------|
| `ACCEPT_EULA` | 接受 EULA 协议 | `Y` | 是 |
| `MSSQL_SA_PASSWORD` | SA 用户密码 | - | 是 |
| `MSSQL_PID` | SQL Server 版本 | `Express` | 否 |
| `TZ` | 时区 | `Asia/Shanghai` | 否 |
| `MSSQL_COLLATION` | 排序规则 | `Chinese_PRC_CI_AS` | 否 |

---

## 使用指南

### 首次访问

1. 部署完成后，访问 http://localhost:8080
2. 默认管理员账号请参考 LearnSite 官方文档
3. 首次登录后请及时修改密码

### 数据持久化

- 应用数据：`./app` 目录
- 数据库数据：`./data` 目录

### 更新应用

```bash
# 停止服务
docker compose -f docker-compose.yml down

# 拉取最新镜像
docker compose -f docker-compose.yml pull

# 重新启动
docker compose -f docker-compose.yml up -d
```

### 查看日志

```bash
# 查看所有服务日志
docker compose -f docker-compose.yml logs -f

# 查看特定服务日志
docker compose -f docker-compose.yml logs -f learnsite
docker compose -f docker-compose.yml logs -f mssql
```

---

## 常见问题

### 1. 端口被占用怎么办？

修改 `docker-compose.yml` 中的端口映射：
```yaml
ports:
  - "8081:8080"  # 将宿主机端口改为 8081
```

### 2. 数据库密码忘记了？

修改 `docker-compose.yml` 中的 `MSSQL_SA_PASSWORD` 和 `DB_PASSWORD`，然后重启服务：
```bash
docker compose -f docker-compose.yml down
docker compose -f docker-compose.yml up -d
```

### 3. 应用无法连接数据库？

检查以下几点：
- `DB_HOST` 是否正确
- `DB_PASSWORD` 是否与 `MSSQL_SA_PASSWORD` 一致
- 数据库容器是否健康运行：`docker ps`
- 防火墙是否允许容器间通信

### 4. 如何备份数据？

```bash
# 备份数据库数据
tar -czf mssql-backup.tar.gz ./data

# 备份应用数据
tar -czf learnsite-backup.tar.gz ./app
```

### 5. 健康检查失败怎么办？

确保 `MSSQL_SA_PASSWORD` 已正确配置，健康检查会自动使用该环境变量。

---

## 项目结构

```
learnsite-docker/
├── docker-compose.yml          # 完整部署（LearnSite + MSSQL）
├── docker-compose.mssql.yml    # 仅部署 MSSQL 数据库
├── docker-compose.learnsite.yml # 仅部署 LearnSite 应用
├── docker-compose.ci.yml       # CI 测试环境
├── deploy.sh                   # 一键部署脚本
└── README.md                   # 本文档
```

---

## 技术支持

- 项目地址：https://gitee.com/realiy/learnsite-docker
- LearnSite 官网：https://gitee.com/nylon26/openlearnsite

---

## 许可证

本项目遵循 LearnSite 项目的许可证。