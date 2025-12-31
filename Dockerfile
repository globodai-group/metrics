# ===================================================================================
# GitHub Metrics - Bun-based Docker Image
# Image: artik0din/008bec2b
# ===================================================================================

# Stage 1: Base with system dependencies
FROM oven/bun:1.1-debian AS base

# Install system dependencies for Chrome/Puppeteer
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    ca-certificates \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    libxss1 \
    libx11-xcb1 \
    libxtst6 \
    libgconf-2-4 \
    lsb-release \
    curl \
    unzip \
    git \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome Stable
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install Deno for miscellaneous scripts
RUN curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh

# Environment variables for Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV PUPPETEER_BROWSER_PATH=google-chrome-stable

# Stage 2: Dependencies installation (cached layer)
FROM base AS deps
WORKDIR /metrics

# Copy package files first for better caching
COPY package.json ./
COPY bunfig.toml ./

# Install dependencies with Bun
RUN bun install --frozen-lockfile || bun install

# Stage 3: Build
FROM deps AS builder
WORKDIR /metrics

# Copy source code
COPY . .

# Build the project
RUN bun run build

# Stage 4: Production
FROM base AS runner
WORKDIR /metrics

# Copy built application
COPY --from=builder /metrics .

# Make entry point executable
RUN chmod +x /metrics/source/app/action/index.mjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Entry point - use bun to run the action
ENTRYPOINT ["bun", "run", "/metrics/source/app/action/index.mjs"]
