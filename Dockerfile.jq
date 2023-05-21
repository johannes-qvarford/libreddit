####################################################################################################
## Builder
####################################################################################################
FROM rust:alpine AS builder

RUN apk add --no-cache musl-dev

WORKDIR /libreddit

# create a new empty project
RUN cargo init
COPY Cargo.toml Cargo.lock ./
# build dependencies, when my source code changes, this build can be cached, we don't need to compile dependency again.
RUN cargo build --target x86_64-unknown-linux-musl --release
# remove the dummy build.
RUN cargo clean -p libreddit

COPY ./build.rs ./
COPY ./static static
COPY ./templates templates
COPY ./src src
COPY ./git .git

RUN cargo build --target x86_64-unknown-linux-musl --release

####################################################################################################
## Final image
####################################################################################################
FROM alpine:latest

# Import ca-certificates from builder
COPY --from=builder /usr/share/ca-certificates /usr/share/ca-certificates
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# Copy our build
COPY --from=builder /libreddit/target/x86_64-unknown-linux-musl/release/libreddit /usr/local/bin/libreddit

# Use an unprivileged user.
RUN adduser --home /nonexistent --no-create-home --disabled-password libreddit
USER libreddit

# Tell Docker to expose port 8080
EXPOSE 8080

# Run a healthcheck every minute to make sure Libreddit is functional
HEALTHCHECK --interval=1m --timeout=3s CMD wget --spider --q http://localhost:8080/settings || exit 1

CMD ["libreddit"]