FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    shellcheck \
    jq \
    ripgrep \
    curl \
    git \
    ca-certificates \
    kcov \
  && rm -rf /var/lib/apt/lists/*

# shfmt
RUN curl -fsSL https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64 \
      -o /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/shfmt

# bats-core
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats \
  && /tmp/bats/install.sh /usr/local \
  && rm -rf /tmp/bats

# Common Python tooling
RUN pip3 install --no-cache-dir pre-commit lizard yamllint detect-secrets

# Common Node tooling
RUN npm install -g markdownlint-cli2 jscpd prettier
