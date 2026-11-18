# TVBox / 影视仓 单仓源工具包

一套可以自己托管、自动更新的影视源生成方案。核心产物是 `config/tvbox.json`，播放器导入它的直链即可用。

---

## 🚀 复制即用（4 步拿到你自己的导入地址）

> 前置：本机装有 `git`，有一个 GitHub 账号。

**第 1 步 —— GitHub 网页新建一个公开空仓库**，比如叫 `my-tvbox-source`（不要勾选初始化 README，保持空仓库）。

**第 2 步 —— 在 `tvbox-source/` 目录执行一键初始化：**

```bash
bash setup.sh
```

脚本会：初始化 git、配置提交模板、设置本仓库提交身份、生成首次提交。过程中问你用户名和邮箱，回车用默认值也行。

**第 3 步 —— 关联远程并推送（把 `<>` 换成你自己的）：**

```bash
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git branch -M main
git push -u origin main
```

**第 4 步 —— 开启自动更新的写权限：**

进仓库 `Settings → Actions → General → Workflow permissions`，勾选 **Read and write permissions** 并保存。否则每 6 小时的自动提交会失败。

✅ 搞定。你的导入地址就是：

```
https://raw.githubusercontent.com/<你的用户名>/<仓库名>/main/config/tvbox.json
```

填进 TVBox / 影视仓 / FongMi 的「配置地址 / 订阅地址」，导入即用。

> 不想跑脚本？手动版等价于：
> ```bash
> cd tvbox-source
> git init
> git config commit.template .gitmessage.txt
> git config user.name "你的名字"
> git config user.email "你的邮箱"
> git add . && git commit -m "chore: init [skip ci]"
> git remote add origin https://github.com/<你>/<仓库>.git
> git branch -M main && git push -u origin main
> ```

---

## 目录结构

```
tvbox-source/
├── .github/workflows/auto-update.yml   # 每 6 小时自动更新并提交
├── .gitignore                          # 忽略缓存/临时/系统文件
├── .gitmessage.txt                     # 规范提交信息模板（setup.sh 自动配置）
├── config/tvbox.json                   # 成品源，播放器消费这个文件
├── scripts/update.py                   # 拉取 → 合并 → 去重 → 写回
├── setup.sh                            # 一键初始化 git 仓库
├── upstream.txt                        # 上游源地址列表（你唯一需要维护的入口）
└── README.md
```

## 源地址是怎么来的

一个「源地址」本质就是**一个公网可访问的 JSON 直链**。播放器访问这个 URL，拿到一份规定结构的 JSON，按里面的 `sites`（点播采集）、`lives`（直播）、`parses`（解析）、`spider`（聚合爬虫）去取数据。

三种常见生成方式：

1. **静态直链** —— 手工维护一个 JSON 文件，放到 GitHub raw / Gitee / 自己服务器，把 URL 填进播放器。最简单，但失效要手动改。
2. **服务端动态生成** —— 如 `https://6.180189.com/?source=json&token=xxx`，服务器按请求实时拼装 JSON 返回，可带授权、按地区分发。需要一台服务器和后端程序。
3. **聚合自动更新**（本工具包）—— 维护一份上游列表，脚本定时拉取多个成熟源，合并各段并按 key 去重，写回 `config/tvbox.json`，GitHub Actions 每 6 小时自动跑一次。既省维护，又能在上游失效时保持可用性。

## 本地使用

```bash
python scripts/update.py --dry-run       # 只看合并结果，不写文件
python scripts/update.py                 # 拉取上游并写回 config/tvbox.json
python scripts/update.py --health-check  # 额外做存活探测，剔除失活站点（较慢）
```

## 自定义

- **加源**：编辑 `upstream.txt`，每行贴一个 TVBox 兼容的 JSON 直链，保存后工作流会自动合并。
- **改频率**：编辑 `auto-update.yml` 里的 cron，`0 */6 * * *` 表示每 6 小时（UTC）。
- **精简站点**：直接改 `config/tvbox.json` 的 `sites` 段，删掉不想要的条目。
- **改提交模板**：编辑 `.gitmessage.txt`；老仓库重跑一次 `git config commit.template .gitmessage.txt` 生效。

## 提交信息规范

`setup.sh` 会把 `.gitmessage.txt` 设为提交模板，之后 `git commit` 不带 `-m` 时自动带出模板。格式 `<type>(<scope>): <subject>`，例如：

```
feat(source): 追加 XX 采集源
fix(script): 修复 JSONC 注释解析
chore: auto update tvbox source [skip ci]
```

## 站点字段速查

| 字段 | 含义 |
| --- | --- |
| `type: 1` | 苹果 CMS 接口，api 形如 `xxx/api.php/provide/vod` |
| `type: 3` | 远程 JS 爬虫，api 指向一个 `spider.js`，由客户端内置 JS 引擎执行 |
| `searchable` | 是否支持搜索 |
| `quickSearch` | 是否支持快速搜索 |
| `filterable` | 是否支持筛选 |
| `categories` | 分类列表 |

## 免责声明

本工具包只做配置的聚合与分发机制，不生产、不存储任何媒体内容。上游地址由使用者自行配置，请遵守所在地法律法规及上游源的服务条款。
