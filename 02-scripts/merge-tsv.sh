#!/bin/bash

# 合并所有文件并去除重复行
cat *.kraken.tsv | awk '!seen[$0]++' > merged_taxonomy.tsv