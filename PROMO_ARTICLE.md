# 🐙 想用 OpenClaw 又怕它瞎胡来？试试这个"笼子"！

---

**OpenClaw** 是真香——能自动帮你操作浏览器、写代码、调度任务。但让它直接在你电脑上撒欢，想想就慌：**万一它误删文件、乱提交代码、给你发些不该发的消息咋办？**

🙄 **别慌！给你装个"笼子"**

---

## 🐣 OpenClaw DevKit —— 容器化开发环境

把 OpenClaw 关进 Docker 容器里跑，跟宿主机彻底隔离：

| 隔离什么 | 怎么隔离 |
| :--- | :--- |
| 📁 文件系统 | 只能访问指定目录，不碰你其他文件 |
| 🌐 网络 | 只暴露本地 127.0.0.1，想乱发消息？门都没有 |
| 🐙 Git 提交 | 给它配个独立身份，谁提交的、谁提交的，一目了然 |
| 🔧 权限 | 最小权限原则，不该动的坚决不动 |

---

## ⚡ 一步启动

```bash
# 克隆
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 配置
cp .env.example .env

# 拉镜像 + 启动
docker pull ghcr.io/hrygo/openclaw-devkit:latest
make up

# 首次配置
make onboard
```

然后访问 http://127.0.0.1:18789 开始玩耍 🎮

---

## 📦 三个版本

| 版本 | 适合谁 |
| :--- | :--- |
| 标准版 | 程序员，写代码、自动化网页 |
| Office 版 | 非技术党，OCR、PDF、批量处理 |
| Java 版 | Java 开发者，需要 JDK 21 |

---

## 🤔 FAQ

**Q: 容器里能上网吗？**
A: 能！内置代理优化，直连 Google/Claude API（需要你宿主机有代理）

**Q: 重启后配置还在吗？**
A: 在！用 Named Volume 持久化，会话、配置都不丢

**Q: Windows 能用吗？**
A: 能！需要 Docker Desktop + WSL2（Win10 21H2+ 或 Win11）

---

**与其担心它搞事情，不如把它关起来 ——**

🔗 GitHub: https://github.com/hrygo/openclaw-devkit

有问题群里问，或者自己看 README（狗头）

