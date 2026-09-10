# CLAUDE.md - Claude Code 项目配置

> 本文件为 Claude Code 提供项目级行为配置。
> **完整项目上下文、架构、开发指南、代码模式库见 [AGENTS.md](AGENTS.md)（单一源）**，本文件仅保留 Claude Code 专属配置，避免重复。

## 上下文管理

- **优先阅读**: `AGENTS.md` 获取完整项目上下文（项目身份、架构、分析流程、依赖、配置、常见任务、代码模式库、性能优化、测试策略）
- **领域术语**: `CONTEXT.md` 提供核心概念与术语对照

## 工具使用策略

| 任务类型 | 首选工具 | 说明 |
|----------|----------|------|
| 文件搜索 | Glob | 比 find 更高效 |
| 内容搜索 | Grep | 比 grep 命令更好用 |
| 代码编辑 | Edit | 增量修改，保留历史 |
| 新文件 | Write | 完整文件创建 |
| Shell 命令 | Bash | 系统操作 |

## 代码生成约定

遵循 `AGENTS.md` 中的代码规范与模式库。要点：

- **类型注解**: 所有函数必须有类型注解（Python 3.10+ 原生语法 `dict[str, str]`）
- **文档字符串**: Google 风格
- **路径处理**: `pathlib.Path` 而非字符串拼接
- **日志记录**: `logging.getLogger(__name__)`

## 相关文件索引

| 文件 | 用途 |
|------|------|
| [AGENTS.md](AGENTS.md) | 完整项目上下文（单一源） |
| [CONTEXT.md](CONTEXT.md) | 领域词汇表与术语对照 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 贡献指南 |
