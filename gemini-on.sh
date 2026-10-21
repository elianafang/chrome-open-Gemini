#!/bin/bash
# 一键开启 Chrome 内置 Gemini (macOS)
# 用法: ./gemini-on.sh [on|off|status|check]   默认 on

set -u

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/glic-switch"
CHROME="/Applications/Google Chrome.app"
REPO="fxw-labs/glic-switch"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [ "$(uname -s)" != "Darwin" ]; then
  red "这个脚本只支持 macOS。Windows/Linux 请直接用 glic-switch: https://github.com/$REPO"
  exit 1
fi

detect_proxy() {
  local out host port
  out=$(scutil --proxy 2>/dev/null)
  if echo "$out" | grep -q "HTTPSEnable : 1"; then
    host=$(echo "$out" | awk '/HTTPSProxy :/ {print $3}')
    port=$(echo "$out" | awk '/HTTPSPort :/ {print $3}')
    [ -n "$host" ] && [ -n "$port" ] && echo "http://$host:$port" && return
  fi
  if echo "$out" | grep -q "SOCKSEnable : 1"; then
    host=$(echo "$out" | awk '/SOCKSProxy :/ {print $3}')
    port=$(echo "$out" | awk '/SOCKSPort :/ {print $3}')
    [ -n "$host" ] && [ -n "$port" ] && echo "socks5h://$host:$port" && return
  fi
}

PROXY="$(detect_proxy || true)"
CURL=(curl -s -m 12)
[ -n "$PROXY" ] && CURL+=(-x "$PROXY")

install_tool() {
  step "安装 glic-switch"
  if [ -x "$BIN" ] || command -v glic-switch >/dev/null 2>&1; then
    green "已安装"
    return 0
  fi
  local arch asset tmp
  case "$(uname -m)" in
    arm64)  arch=arm64 ;;
    x86_64) arch=amd64 ;;
    *) red "不支持的芯片: $(uname -m)"; return 1 ;;
  esac
  asset="glic-switch_darwin_${arch}.tar.gz"
  tmp=$(mktemp -d)
  echo "下载 $asset ..."
  if ! curl -fsSL -m 120 ${PROXY:+-x "$PROXY"} -o "$tmp/$asset" \
      "https://github.com/$REPO/releases/latest/download/$asset"; then
    red "下载失败。请确认代理已开启,或手动从 https://github.com/$REPO/releases 下载。"
    return 1
  fi
  tar -xzf "$tmp/$asset" -C "$tmp" || { red "解压失败"; return 1; }
  mkdir -p "$BIN_DIR"
  install -m 755 "$tmp/glic-switch" "$BIN" || { red "安装失败"; return 1; }
  xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true
  rm -rf "$tmp"
  green "已安装到 $BIN"
}

run_glic() {
  if [ -x "$BIN" ]; then "$BIN" "$@"; else glic-switch "$@"; fi
}

check_env() {
  step "检查环境"
  if [ ! -d "$CHROME" ]; then
    red "没有找到 Google Chrome,请先安装。"
    return 1
  fi
  local ver major
  ver=$("$CHROME/Contents/MacOS/Google Chrome" --version 2>/dev/null | awk '{print $3}')
  major=${ver%%.*}
  echo "Chrome 版本: ${ver:-未知}"
  if [ -n "$major" ] && [ "$major" -lt 147 ] 2>/dev/null; then
    red "Chrome 版本需要 147 及以上,请先升级。"
    return 1
  fi
  if [ -n "$PROXY" ]; then
    echo "检测到系统代理: $PROXY"
  else
    yellow "没有检测到系统代理。如果你在中国大陆,请先打开代理软件的“系统代理”。"
  fi
  return 0
}

check_node() {
  step "检查代理节点"
  local country code redirect
  country=$("${CURL[@]}" https://api.country.is | sed -n 's/.*"country":"\([A-Z]*\)".*/\1/p')
  if [ -z "$country" ]; then
    red "无法获取出口地区,请检查网络和代理是否正常。"
    return 1
  fi
  echo "出口地区: $country"
  if [ "$country" = "CN" ] || [ "$country" = "HK" ]; then
    red "出口在 $country,Gemini 不可用。请换成美国节点。"
    return 1
  fi
  read -r code redirect < <("${CURL[@]}" -o /dev/null -w "%{http_code} %{redirect_url}\n" https://gemini.google.com/app)
  case "$redirect" in
    *google.com/sorry*)
      red "这个节点的 IP 被 Google 风控(跳转到验证页)。"
      red "不是地区问题,是这个 IP 被标记了。请换一个节点(优先美国),再重新运行。"
      return 1 ;;
  esac
  if [ "$code" = "200" ]; then
    green "gemini.google.com 可以正常访问"
    return 0
  fi
  yellow "gemini.google.com 返回 $code,可能不稳定,仍然继续。"
  return 0
}

confirm_restart() {
  if pgrep -x "Google Chrome" >/dev/null 2>&1; then
    echo
    yellow "Chrome 正在运行,继续会关闭并重启它。请先保存好网页里未提交的内容。"
    if [ -t 0 ]; then
      read -r -p "继续吗? [y/N] " ans
      case "$ans" in y|Y|yes|YES) ;; *) echo "已取消。"; exit 0 ;; esac
    fi
  fi
}

do_on() {
  check_env || exit 1
  install_tool || exit 1
  check_node || { echo; yellow "节点不可用也可以强制继续,但大概率看不到 Gemini。"; exit 1; }
  confirm_restart
  step "开启 Gemini"
  run_glic on
  sleep 4
  step "最终状态"
  run_glic status
  echo
  green "完成。请在 Chrome 右上角找 Gemini 图标。"
  echo "以后要用 Gemini,请运行本脚本启动 Chrome,不要点 Dock 图标,否则配置会被重置。"
}

case "${1:-on}" in
  on)     do_on ;;
  off)    install_tool || exit 1; confirm_restart; run_glic off ;;
  status) install_tool || exit 1; run_glic status ;;
  check)  check_env && check_node ;;
  *) echo "用法: $0 [on|off|status|check]"; exit 1 ;;
esac
