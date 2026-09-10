# MICOS-2024 GitHub Copilot 指令

> 完整项目架构、开发指南、代码模式库、测试与提交规范见 [AGENTS.md](../AGENTS.md)。
> 本文件仅补充 Copilot 代码生成相关的细节要点，避免与 AGENTS.md 重复。

## Python 代码生成细节

- **类型注解**: Python 3.10+ 原生语法 `dict[str, str]` / `list[Path]` 而非 `Dict` / `List`
- **格式化**: Black 88 字符 + isort (profile=black)
- **文档字符串**: Google 风格
- **路径**: `pathlib.Path` 而非字符串拼接
- **日志**: `logging.getLogger(__name__)`
- **错误处理**: 标准异常，避免过度 try/catch（详见 AGENTS.md 代码模式库）

```python
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

def process_sample(
    sample_id: str,
    input_path: Path,
    output_dir: Path,
    threads: int = 4,
) -> dict[str, Path]:
    """处理单个样本.

    Args:
        sample_id: 样本标识符
        input_path: 输入 FASTQ 文件路径
        output_dir: 输出目录
        threads: 线程数

    Returns:
        包含输出文件路径的字典

    Raises:
        FileNotFoundError: 输入文件不存在
    """
    ...
```

## 命名约定

| 类型 | 约定 | 示例 |
|------|------|------|
| 模块 | snake_case | `quality_control.py` |
| 类 | PascalCase | `FastQCRunner` |
| 函数 | snake_case | `run_quality_control` |
| 常量 | UPPER_SNAKE_CASE | `DEFAULT_THREADS` |

## CLI (Click 框架)

```python
import click

@click.group()
def cli():
    """MICOS-2024 宏基因组分析平台."""

@cli.command()
@click.option('--input-dir', required=True, help='输入目录')
@click.option('--threads', default=16, help='线程数')
def full_run(input_dir: str, threads: int):
    """运行完整分析流程."""
    ...
```

## 配置系统要点

- **实际生效字段**: `paths.input_dir` / `paths.output_dir` / `paths.databases.{kraken2,kneaddata}` / `resources.max_threads`
- 其他 analysis.yaml 字段为愿景参数，CLI 当前不读取
- 样本发现通过 FASTQ 文件名 (`*_R1.fastq.gz`)；可选 `--metadata config/samples.tsv` 按 `sample-id` 列 join 填充 `Sample.metadata`
- 配置模型: `micos.config.AnalysisConfig` (Pydantic)
