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

RUN cargo build --release --bin server

FROM debian:stable-slim
WORKDIR /code
RUN apt update \
    && apt install -y openssl ca-certificates \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /code/target/release/server ./

ENTRYPOINT ["/code/server"]
EXPOSE 8000