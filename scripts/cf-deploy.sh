#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_PATH="$(bash "${SCRIPT_DIR}/cf-config.sh")"

cd "${REPO_ROOT}"

echo "==> using wrangler config: ${CONFIG_PATH}"

bash "${SCRIPT_DIR}/cf-validate-config.sh" "${CONFIG_PATH}"

rm -rf .next .open-next

npx opennextjs-cloudflare build

# 先部署 Worker，让 Cloudflare 创建/绑定 D1 资源
echo "==> deploying worker"
npx opennextjs-cloudflare deploy -c "${CONFIG_PATH}"

# 尝试初始化 D1 数据库，失败不阻断
echo "==> applying D1 schema"
if npx wrangler d1 execute DB \
  --remote \
  --file="${REPO_ROOT}/db/schema.sql" \
  -c "${CONFIG_PATH}" 2>/dev/null; then
  echo "==> D1 schema applied"
else
  echo "⚠️ D1 schema failed. Please apply manually via Cloudflare Dashboard after deployment."
fi

if [[ -f "${REPO_ROOT}/db/seed-template.sql" ]]; then
  echo "==> applying template defaults"
  if npx wrangler d1 execute DB \
    --remote \
    --file="${REPO_ROOT}/db/seed-template.sql" \
    -c "${CONFIG_PATH}" 2>/dev/null; then
    echo "==> template defaults applied"
  else
    echo "⚠️ D1 seed failed. Please apply manually via Cloudflare Dashboard."
  fi
fi

echo "==> deploy complete"
