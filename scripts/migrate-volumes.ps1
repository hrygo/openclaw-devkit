#Requires -Version 5.1
<#
.SYNOPSIS
    OpenClaw DevKit 卷迁移工具 (PowerShell 版本)

.DESCRIPTION
    将 Docker Compose 卷的项目标签从 openclaw 迁移到 openclaw-devkit

.EXAMPLE
    .\migrate-volumes.ps1
    .\migrate-volumes.ps1 -AutoConfirm

.NOTES
    Windows 用户也可使用 Git Bash 运行 migrate-volumes.sh
#>

param(
    [switch]$AutoConfirm,
    [switch]$Help
)

if ($Help) {
    Write-Host "用法: .\migrate-volumes.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -AutoConfirm    自动确认，无需交互"
    Write-Host "  -Help           显示帮助信息"
    Write-Host ""
    Write-Host "功能: 将 Docker Compose 卷的项目标签从 openclaw 迁移到 openclaw-devkit"
    Write-Host ""
    Write-Host "提示: Windows 用户也可使用 Git Bash 运行 migrate-volumes.sh"
    exit 0
}

# 颜色定义
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$CYAN = "`e[36m"
$BOLD = "`e[1m"
$NC = "`e[0m"

# 配置
$VOLUMES = @("openclaw-devkit-home", "openclaw-claude-home")
$BACKUP_DIR = Join-Path $env:TEMP "openclaw-volume-backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "${GREEN}=========================================="
Write-Host "OpenClaw DevKit 卷迁移工具 (PowerShell)"
Write-Host "==========================================${NC}"
Write-Host ""

# 检查是否需要迁移
$NEED_MIGRATION = $false
foreach ($vol in $VOLUMES) {
    try {
        $volInfo = docker volume inspect $vol 2>$null
        if ($volInfo) {
            $project = ($volInfo | ConvertFrom-Json).Labels.'com.docker.compose.project'
            if ($project -eq "openclaw") {
                $NEED_MIGRATION = $true
                Write-Host "${YELLOW}⚠️  检测到旧标签: $vol (project=openclaw)${NC}"
            } else {
                Write-Host "${GREEN}✓ $vol 标签正常 (project=$project)${NC}"
            }
        }
    } catch {
        # 卷不存在，跳过
    }
}

if (-not $NEED_MIGRATION) {
    Write-Host "${GREEN}✅ 所有卷标签正常，无需迁移${NC}"
    exit 0
}

Write-Host ""
Write-Host "${YELLOW}⚠️  警告：此操作将：${NC}"
Write-Host "  1. 备份现有卷数据到 $BACKUP_DIR"
Write-Host "  2. 删除旧卷（project=openclaw）"
Write-Host "  3. 重新创建新卷（project=openclaw-devkit）"
Write-Host "  4. 恢复数据"
Write-Host ""
Write-Host "预计耗时：1-3 分钟（取决于数据量）"
Write-Host ""

if (-not $AutoConfirm) {
    $confirm = Read-Host "是否继续？(yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "已取消操作"
        exit 0
    }
}

# 停止服务
Write-Host ""
Write-Host "${GREEN}>>> 停止现有服务...${NC}"
docker compose down 2>$null

# 创建备份目录
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
Write-Host "${GREEN}✓ 创建备份目录: $BACKUP_DIR${NC}"

# 备份卷数据
Write-Host ""
Write-Host "${GREEN}>>> 备份卷数据...${NC}"
foreach ($vol in $VOLUMES) {
    try {
        $volInfo = docker volume inspect $vol 2>$null
        if ($volInfo) {
            Write-Host "  备份 $vol..."
            docker run --rm -v "${vol}:/source:ro" -v "${BACKUP_DIR}:/backup" alpine tar czf "/backup/${vol}.tar.gz" -C /source . 2>$null
        }
    } catch {
        Write-Host "${YELLOW}  跳过不存在的卷: $vol${NC}"
    }
}

Write-Host "${GREEN}✓ 备份完成，文件列表：${NC}"
Get-ChildItem $BACKUP_DIR | Format-Table Name, Length

# 删除旧卷
Write-Host ""
Write-Host "${GREEN}>>> 删除旧卷...${NC}"
foreach ($vol in $VOLUMES) {
    try {
        $volInfo = docker volume inspect $vol 2>$null
        if ($volInfo) {
            Write-Host "  删除 $vol..."
            docker volume rm $vol | Out-Null
        }
    } catch {
        # 卷不存在，跳过
    }
}
Write-Host "${GREEN}✓ 旧卷已删除${NC}"

# 重新创建卷
Write-Host ""
Write-Host "${GREEN}>>> 重新创建卷...${NC}"
docker compose up --no-start 2>$null
Write-Host "${GREEN}✓ 新卷已创建${NC}"

# 验证新卷标签
Write-Host ""
Write-Host "${GREEN}>>> 验证新卷标签...${NC}"
foreach ($vol in $VOLUMES) {
    try {
        $volInfo = docker volume inspect $vol 2>$null
        if ($volInfo) {
            $project = ($volInfo | ConvertFrom-Json).Labels.'com.docker.compose.project'
            Write-Host "  $vol : project=$project"
        }
    } catch {
        # 卷不存在，跳过
    }
}

# 恢复数据
Write-Host ""
Write-Host "${GREEN}>>> 恢复数据到新卷...${NC}"
foreach ($vol in $VOLUMES) {
    $backupFile = Join-Path $BACKUP_DIR "${vol}.tar.gz"
    if (Test-Path $backupFile) {
        Write-Host "  恢复 $vol..."
        docker run --rm -v "${vol}:/target" -v "${BACKUP_DIR}:/backup" alpine sh -c "cd /target && tar xzf /backup/${vol}.tar.gz" 2>$null
    }
}
Write-Host "${GREEN}✓ 数据已恢复${NC}"

# 清理
Write-Host ""
Write-Host "${GREEN}=========================================="
Write-Host "✅ 迁移完成！"
Write-Host "==========================================${NC}"
Write-Host ""
Write-Host "备份文件保留在: $BACKUP_DIR"
Write-Host "可通过以下命令验证："
Write-Host "  make up      # 启动服务"
Write-Host "  make logs    # 查看日志"
Write-Host ""
Write-Host "如需清理备份文件："
Write-Host "  Remove-Item -Recurse -Force $BACKUP_DIR"
Write-Host ""
