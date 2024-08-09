FROM rustlang/rust:nightly AS builder

RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Update default packages
RUN apt-get update -y

WORKDIR /code
ENV CARGO_HOME=/code/.cargo
COPY . .

RUN cargo build --release --features revm --bin prover_server  

FROM debian:stable-slim
WORKDIR /code
RUN apt update \
    && apt install -y openssl ca-certificates \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /code/target/release/prover_server ./
COPY --from=builder /code/data/vk.json ./data/vk.json

CMD ["/code/prover_server"]
EXPOSE 8000
