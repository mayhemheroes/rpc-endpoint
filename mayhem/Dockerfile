FROM golang:1.18 as builder

COPY . /rpc-endpoint
WORKDIR /rpc-endpoint/mayhem

RUN go install github.com/dvyukov/go-fuzz/go-fuzz@latest github.com/dvyukov/go-fuzz/go-fuzz-build@latest
RUN go get github.com/dvyukov/go-fuzz/go-fuzz-dep
RUN apt update && apt install -y clang


RUN go-fuzz-build -libfuzzer -o fuzzServer.a && \
    clang -fsanitize=fuzzer fuzzServer.a -o fuzzServer.libfuzzer

FROM debian:bookworm-slim
COPY --from=builder /rpc-endpoint/mayhem/fuzzServer.libfuzzer /