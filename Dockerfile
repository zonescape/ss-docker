FROM rust:1.89.0-slim-trixie AS builder

ARG TARGETARCH

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq musl-dev

WORKDIR /root/shadowsocks-rust

ADD . .

RUN case "$TARGETARCH" in \
    "386") \
        RUST_TARGET="i686-unknown-linux-musl" \
    ;; \
    "amd64") \
        RUST_TARGET="x86_64-unknown-linux-musl" \
    ;; \
    "arm64") \
        RUST_TARGET="aarch64-unknown-linux-musl" \
    ;; \
    *) \
        echo "Doesn't support $TARGETARCH architecture" \
        exit 1 \
    ;; \
    esac \
    && rustup target add "$RUST_TARGET" \
    && cargo build --target "$RUST_TARGET" --release --features "full" \
    && mv target/$RUST_TARGET/release/ss* target/release/

FROM alpine:3.22 AS sslocal

# NOTE: Please be careful to change the path of these binaries, refer to #1149 for more information.
COPY --from=builder /root/shadowsocks-rust/target/release/sslocal /usr/bin/
COPY --from=builder /root/shadowsocks-rust/examples/config.json /etc/shadowsocks-rust/
COPY --from=builder /root/shadowsocks-rust/docker/docker-entrypoint.sh /usr/bin/

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "sslocal", "--log-without-time", "-c", "/etc/shadowsocks-rust/config.json" ]

FROM alpine:3.22 AS ssserver

COPY --from=builder /root/shadowsocks-rust/target/release/ssserver /usr/bin/
COPY --from=builder /root/shadowsocks-rust/examples/config.json /etc/shadowsocks-rust/
COPY --from=builder /root/shadowsocks-rust/docker/docker-entrypoint.sh /usr/bin/

ENTRYPOINT [ "docker-entrypoint.sh" ]

CMD [ "ssserver", "--log-without-time", "-a", "nobody", "-c", "/etc/shadowsocks-rust/config.json" ]