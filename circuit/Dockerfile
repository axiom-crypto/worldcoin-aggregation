FROM rustlang/rust:nightly AS builder

ARG VERSION=v1

RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Update default packages
RUN apt-get update -y
RUN apt-get install -y clang

WORKDIR /code
ENV CARGO_HOME=/code/.cargo
COPY . .

RUN cargo build --release --features "asm, ${VERSION}" --bin prover_server --bin scheduler_server

FROM debian:stable-slim
WORKDIR /code
RUN apt update \
    && apt install -y openssl ca-certificates \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /code/target/release/prover_server ./
COPY --from=builder /code/target/release/scheduler_server ./

COPY --from=builder /code/data/vk.json ./data/vk.json

# see https://github.com/jemalloc/jemalloc/blob/dev/TUNING.md
# this sets decay to 1GB, DO NOT USE narenas=1
ENV JEMALLOC_SYS_WITH_MALLOC_CONF="background_thread:true,metadata_thp:always,dirty_decay_ms:1000000,muzzy_decay_ms:1000000,abort_conf:true"

# default entrance, can be overridden by --entrypoint
CMD ["/code/prover_server"]
EXPOSE 8000
