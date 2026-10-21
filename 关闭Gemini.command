#!/bin/bash
cd "$(dirname "$0")" || exit 1
bash ./gemini-on.sh off
echo
read -r -p "按回车键关闭窗口..." _
