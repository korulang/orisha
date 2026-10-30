# syntax=docker/dockerfile:1.7
#
# Orisha TechEmpower entry — builds orisha/techempower/main.k from the
# Koru toolchain. Postgres arrives at runtime as TFB_DATABASE_HOST.

FROM ubuntu:24.04 AS build
ARG KORU_REF=main
ARG ORISHA_REF=main
ARG KORU_LIBS_REF=main
ARG ZIG_VERSION=0.15.2
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git xz-utils pkg-config libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
        amd64) ZIG_ARCH=x86_64 ;; \
        arm64) ZIG_ARCH=aarch64 ;; \
        *) echo "unsupported arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" \
        | tar -xJ -C /opt; \
    ln -sf "/opt/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig

WORKDIR /src
RUN git clone --depth 1 --branch "${KORU_REF}" https://github.com/korulang/koru.git koru \
    && git clone --depth 1 --branch "${KORU_LIBS_REF}" https://github.com/korulang/koru-libs.git koru-libs \
    && git clone --depth 1 --branch "${ORISHA_REF}" https://github.com/korulang/orisha.git orisha

RUN cd koru && zig build && install -m755 zig-out/bin/koruc /usr/local/bin/koruc

WORKDIR /src/orisha/techempower
RUN mkdir -p /out /usr/local \
    && rm -rf /usr/local/src /usr/local/koru_std \
    && ln -sfn /src/koru/src /usr/local/src \
    && ln -sfn /src/koru/koru_std /usr/local/koru_std \
    && test -f /usr/local/src/ast.zig \
    && rm -rf .zig-cache \
        backend.zig backend_output_emitted.zig build.zig build_backend.zig build_output.zig \
        output_emitted.zig program.ast.json compiler_env.zig a.out \
    && koruc main.k --release=fast --build=race \
    && install -m755 a.out /out/orisha-techempower

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates libssl3 zlib1g \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/orisha-techempower /orisha-techempower
EXPOSE 8080
ENTRYPOINT ["/orisha-techempower"]
