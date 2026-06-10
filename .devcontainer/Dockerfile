# mcr.microsoft.com/devcontainers/base:ubuntu-24.04 pinned by digest.
# Dependabot will refresh both the tag and digest together.

# kcov was dropped from the Ubuntu 24.04 (noble) apt archive, so build it
# from source in a throwaway stage and copy the install into the final image.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae AS kcov-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils-dev \
    ca-certificates \
    cmake \
    g++ \
    git \
    libcurl4-openssl-dev \
    libdw-dev \
    libelf-dev \
    libiberty-dev \
    libssl-dev \
    make \
    python3 \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v43 https://github.com/SimonKagstrom/kcov.git /tmp/kcov \
  && cmake -S /tmp/kcov -B /tmp/kcov/build -DCMAKE_BUILD_TYPE=Release \
  && cmake --build /tmp/kcov/build -j"$(nproc)" \
  && DESTDIR=/tmp/kcov-install cmake --install /tmp/kcov/build

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

# binutils and libdw1t64 are runtime dependencies of the kcov binary built above.
RUN apt-get update && apt-get install -y --no-install-recommends \
    shellcheck \
    jq \
    ripgrep \
    curl \
    git \
    ca-certificates \
    binutils \
    libcurl4t64 \
    libdw1t64 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=kcov-build /tmp/kcov-install/usr/local/ /usr/local/

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
