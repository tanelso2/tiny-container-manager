FROM nimlang/nim

COPY ./ .

RUN nimble refresh -y

RUN nimble build

RUN nimble test
