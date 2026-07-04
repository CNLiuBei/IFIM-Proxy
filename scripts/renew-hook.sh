#!/usr/bin/env bash
set -u

INSTALL_DIR="/etc/stable-proxy-stack"

if nginx -t 2>/dev/null; then
    systemctl reload nginx 2>/dev/null || true
fi

if [[ -f "${INSTALL_DIR}/sing-box/sing-box" ]]; then
    systemctl restart sing-box.service 2>/dev/null || true
fi
