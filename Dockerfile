FROM ubuntu:latest

RUN apt update && apt install -y curl

RUN apt update && apt install -y gcc

RUN apt update && apt install -y tar xz-utils

# RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y


COPY ./tiny_container_manager.nimble .

COPY ./deployment/ .

COPY ./ .

RUN ./deployment/install-nim.sh

ENV PATH "$PATH:/root/.nimble/bin"

RUN nimble choosenim

RUN nimble build -y

RUN nimble test
