# 🐙 想用 OpenClaw 又怕它瞎胡来？试试这个"笼子"！

---

**OpenClaw** 有多香不用我说了吧？🤤 能自动帮你操作浏览器、写代码、调度任务，堪称程序员贴心小棉袄。

但让它直接在你电脑上撒欢——
> ❓ 万一它误删文件咋整？
> ❓ 万一它乱提交代码到公司仓库咋整？
> ❓ 万一它给你通讯录里的人疯狂发消息咋整？

🙄 **别慌！给它装个"笼子"就好了**

---

## 🐣 OpenClaw DevKit —— 容器化开发环境

把 OpenClaw 关进 Docker 容器里跑，跟宿主机彻底隔离 👮‍♂️

| 隔离什么 | 怎么隔离 |
| :--- | :--- |
| 📁 文件系统 | 只能访问指定目录，想碰你其他文件？门都没有 🚫 |
| 🌐 网络 | 只暴露本地 127.0.0.1，想乱发消息？不可能 🚫 |
| 🐙 Git 提交 | 给它配个独立身份，人提交还是 AI 提交，一目了然 🔍 |
| 🔧 权限 | 最小权限原则，不该动的坚决不动 🤐 |

> 💡 **一句话**：出事了？好办！删掉容器重来呗~ 🎉

---

## ⚡ 一步启动

```bash
# 1. 克隆代码
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. 准备配置并安装 (自动拉取/启动容器)
cp .env.example .env
make install

# 3. 首次配置向导
make onboard
```

然后访问 🔗 http://127.0.0.1:18789 开始玩耍 🎮

---

## 📦 三个版本，总有一款适合你

| 版本 | 适合谁 | 独门绝技 |
| :--- | :--- | :--- |
| 🌟 标准版 | 程序员 | Go + Node + Python + AI 编程助手 |
| 📄 Office 版 | 非技术党 | OCR 识别 PDF、批量处理文档 |
| ☕ Java 版 | Java 开发者 | JDK 21 + Gradle + Maven |

---

## 🤔 FAQ

**Q: 容器里能上网吗？** 🌐
> A: 能！内置代理优化，直连 Google/Claude API（前提是你宿主机有代理）

**Q: 重启后配置还在吗？** 💾
> A: 在！用 Named Volume 持久化，会话、配置纹丝不动

**Q: Windows 能用吗？** 🪟
> A: 能！需要 Docker Desktop + WSL2（Win10 21H2+ 或 Win11）

**Q: 不会 Docker 咋办？** 😰
> A: 没事！Makefile 封装好了，照着命令敲就行 🤗

---

**与其担心它搞事情，不如把它关起来 ——**

🔗 GitHub: https://github.com/hrygo/openclaw-devkit

有问题群里问，或者自己看 README 😏

