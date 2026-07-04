#!/usr/bin/env bash
# 刷新订阅页 HTML + 二维码（已安装机器修复用）
set -euo pipefail

INSTALL_DIR="/etc/stable-proxy-stack"
WEB_ROOT="/var/www/stable-proxy"
PANEL_DIR="${WEB_ROOT}/panel"
GITHUB_REPO="${GITHUB_REPO:-CNLiuBei/stable-proxy-stack}"
TS="$(date +%s)"

[[ -f "${PANEL_DIR}/config.json" ]] || { echo "config.json 不存在: ${PANEL_DIR}/config.json"; exit 1; }

command -v jq >/dev/null 2>&1 || apt-get install -y -qq jq >/dev/null 2>&1 || apt-get install -y jq
command -v python3 >/dev/null 2>&1 || apt-get install -y -qq python3 >/dev/null 2>&1 || apt-get install -y python3
command -v qrencode >/dev/null 2>&1 || apt-get install -y -qq qrencode >/dev/null 2>&1 || apt-get install -y qrencode
command -v curl >/dev/null 2>&1 || apt-get install -y -qq curl >/dev/null 2>&1 || apt-get install -y curl

sub_url=$(jq -r .subUrl "${PANEL_DIR}/config.json")
reality_link=$(jq -r .realityLink "${PANEL_DIR}/config.json")
hy2_link=$(jq -r .hy2Link "${PANEL_DIR}/config.json")

sha=$(curl -fsSL --max-time 15 -H "User-Agent: stable-proxy-refresh" \
    "https://api.github.com/repos/${GITHUB_REPO}/commits/main" \
    | sed -n 's/.*"sha": "\([a-f0-9]\{40\}\)".*/\1/p' | head -1)

html_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/assets/subscribe-panel.html?t=${TS}"
[[ -n "${sha}" ]] && html_url="https://raw.githubusercontent.com/${GITHUB_REPO}/${sha}/assets/subscribe-panel.html?t=${TS}"

curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" "${html_url}" \
    -o "${PANEL_DIR}/index.html"

if ! grep -q 'cards-row' "${PANEL_DIR}/index.html"; then
    echo "错误: 下载的仍是旧版页面（无 cards-row）"
    echo "请执行: grep cards-row ${PANEL_DIR}/index.html"
    exit 1
fi

if ! grep -q '__PANEL_CONFIG__' "${PANEL_DIR}/index.html"; then
    echo "错误: 页面模板异常"
    exit 1
fi

python3 - "${PANEL_DIR}/config.json" "${PANEL_DIR}/index.html" <<'PY'
import json, pathlib, sys
cfg_path, html_path = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
html = html_path.read_text(encoding="utf-8")
html = html.replace("__PANEL_CONFIG__", json.dumps(cfg, ensure_ascii=False))
html_path.write_text(html, encoding="utf-8")
PY

qrencode -o "${PANEL_DIR}/qr-sub.png" -s 5 -m 1 "${sub_url}"
qrencode -o "${PANEL_DIR}/qr-reality.png" -s 5 -m 1 "${reality_link}"
qrencode -o "${PANEL_DIR}/qr-hy2.png" -s 5 -m 1 "${hy2_link}"
chmod 644 "${PANEL_DIR}/index.html" "${PANEL_DIR}"/qr-*.png

if [[ -f /etc/nginx/conf.d/stable-proxy.conf ]] \
    && ! grep -q 'Cache-Control.*no-store' /etc/nginx/conf.d/stable-proxy.conf; then
    sed -i '/alias \/var\/www\/stable-proxy\/panel\/;/a\        add_header Cache-Control "no-store, no-cache, must-revalidate";' \
        /etc/nginx/conf.d/stable-proxy.conf 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
fi

panel_url=$(jq -r .panelUrl "${PANEL_DIR}/config.json")
echo "订阅页已刷新（三列布局 v0.0.12）: ${panel_url}"
echo "验证: grep -c cards-row ${PANEL_DIR}/index.html"
grep -c 'cards-row' "${PANEL_DIR}/index.html" || true
echo "请用浏览器 Ctrl+F5 或无痕窗口打开"
