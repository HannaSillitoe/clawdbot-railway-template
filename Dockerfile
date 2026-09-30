# Railway wrapper runtime using OpenClaw's published release package.
# This avoids compiling the full OpenClaw source/plugin workspace inside Railway.
FROM node:24-bookworm

ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
    python3 \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Install the exact published OpenClaw release using its supported npm path.
# npm 12 requires explicit lifecycle-script approval for OpenClaw.
ARG OPENCLAW_VERSION=2026.9.7
RUN npm install -g npm@latest \
  && npm install -g "openclaw@${OPENCLAW_VERSION}" --allow-scripts=openclaw \
  && openclaw --version

# Preserve the legacy path expected by this Railway wrapper.
RUN ln -s "$(npm root -g)/openclaw" /openclaw \
  && test -f /openclaw/dist/entry.js

# Keep pnpm available for existing container-local workflows.
RUN corepack enable

# Persist user-installed tools by default by targeting the Railway volume.
# OpenClaw itself is baked into /usr/local above; these settings apply at runtime.
ENV NPM_CONFIG_PREFIX=/data/npm
ENV NPM_CONFIG_CACHE=/data/npm-cache
ENV PNPM_HOME=/data/pnpm
ENV PNPM_STORE_DIR=/data/pnpm-store
ENV PATH="/data/npm/bin:/data/pnpm:${PATH}"

WORKDIR /app

# Railway wrapper dependencies.
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY src ./src

# The wrapper listens on Railway's injected $PORT.
EXPOSE 8080

ENTRYPOINT ["tini", "--"]
CMD ["node", "src/server.js"]
