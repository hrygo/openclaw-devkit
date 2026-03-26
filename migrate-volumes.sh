#!/bin/bash
set -euo pipefail

# ==============================================================================
# OpenClaw DevKit 卷迁移脚本
# 功能：将 Docker Compose 卷的项目标签从 openclaw 改为 openclaw-devkit
# 场景：存量用户升级后出现卷警告时执行
# ==============================================================================

VOLUMES=("openclaw-devkit-home" "openclaw-claude-home")
BACKUP_DIR="/tmp/openclaw-volume-backup-$(date +%Y%m%d_%H%M%S)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "OpenClaw DevKit 卷迁移工具"
echo -e "==========================================${NC}"
echo ""

# 检查是否需要迁移
NEED_MIGRATION=false
for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        PROJECT=$(docker volume inspect "$vol" --format '{{index .Labels "com.docker.compose.project"}}' 2>/dev/null || echo "none")
        if [[ "$PROJECT" == "openclaw" ]]; then
            NEED_MIGRATION=true
            echo -e "${YELLOW}⚠️  检测到旧标签: $vol (project=openclaw)${NC}"
        else
            echo -e "${GREEN}✓ $vol 标签正常 (project=$PROJECT)${NC}"
        fi
    fi
done

if [[ "$NEED_MIGRATION" == "false" ]]; then
    echo -e "${GREEN}✅ 所有卷标签正常，无需迁移${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}⚠️  警告：此操作将：${NC}"
echo "  1. 备份现有卷数据到 ${BACKUP_DIR}"
echo "  2. 删除旧卷（project=openclaw）"
echo "  3. 重新创建新卷（project=openclaw-devkit）"
echo "  4. 恢复数据"
echo ""
echo "预计耗时：1-3 分钟（取决于数据量）"
echo ""
read -p "是否继续？(yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "已取消操作"
    exit 0
fi

# 停止服务
echo ""
echo -e "${GREEN}>>> 停止现有服务...${NC}"
docker compose down 2>/dev/null || true

# 创建备份目录
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}✓ 创建备份目录: $BACKUP_DIR${NC}"

# 备份卷数据
echo ""
echo -e "${GREEN}>>> 备份卷数据...${NC}"
for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        echo "  备份 $vol..."
        docker run --rm \
            -v "$vol:/source:ro" \
            -v "$BACKUP_DIR:/backup" \
            alpine tar czf "/backup/${vol}.tar.gz" -C /source . 2>/dev/null || {
            echo -e "${RED}✗ 备份失败: $vol${NC}"
            exit 1
        }
    else
        echo -e "${YELLOW}  跳过不存在的卷: $vol${NC}"
    fi
done

echo -e "${GREEN}✓ 备份完成，文件列表：${NC}"
ls -lh "$BACKUP_DIR"

# 删除旧卷
echo ""
echo -e "${GREEN}>>> 删除旧卷...${NC}"
for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        echo "  删除 $vol..."
        docker volume rm "$vol" || {
            echo -e "${RED}✗ 删除失败: $vol${NC}"
            exit 1
        }
    fi
done
echo -e "${GREEN}✓ 旧卷已删除${NC}"

# 重新创建卷（会自动带上 openclaw-devkit 项目标签）
echo ""
echo -e "${GREEN}>>> 重新创建卷...${NC}"
docker compose up --no-start
echo -e "${GREEN}✓ 新卷已创建${NC}"

# 验证新卷标签
echo ""
echo -e "${GREEN}>>> 验证新卷标签...${NC}"
for vol in "${VOLUMES[@]}"; do
    PROJECT=$(docker volume inspect "$vol" --format '{{index .Labels "com.docker.compose.project"}}' 2>/dev/null || echo "none")
    echo "  $vol: project=$PROJECT"
done

# 恢复数据
echo ""
echo -e "${GREEN}>>> 恢复数据到新卷...${NC}"
for vol in "${VOLUMES[@]}"; do
    if [[ -f "$BACKUP_DIR/${vol}.tar.gz" ]]; then
        echo "  恢复 $vol..."
        docker run --rm \
            -v "$vol:/target" \
            -v "$BACKUP_DIR:/backup" \
            alpine sh -c "cd /target && tar xzf /backup/${vol}.tar.gz" || {
            echo -e "${RED}✗ 恢复失败: $vol${NC}"
            exit 1
        }
    fi
done
echo -e "${GREEN}✓ 数据已恢复${NC}"

# 清理
echo ""
echo -e "${GREEN}=========================================="
echo "✅ 迁移完成！"
echo -e "==========================================${NC}"
echo ""
echo "备份文件保留在: $BACKUP_DIR"
echo "可通过以下命令验证："
echo "  make up      # 启动服务"
echo "  make logs    # 查看日志"
echo ""
echo "如需清理备份文件："
echo "  rm -rf $BACKUP_DIR"
echo ""
