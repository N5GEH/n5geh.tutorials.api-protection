FROM kong:3.5
LABEL description="Alpine + Kong  + kong-oidc plugin + LUA Plugins"
USER root
# RUN apk add --update nodejs npm python3 make g++ && rm -rf /var/cache/apk/*
# RUN npm install --unsafe -g kong-pdk@0.5.3
ENV term xterm
RUN apt-get update && apt-get install -y \
    vim curl git gcc make musl-dev unzip libssl-dev

RUN curl -fSL https://luarocks.org/manifests/daurnimator/luaossl-20250929-0.src.rock -o /tmp/luaossl-20250929-0.src.rock
RUN curl -fSL https://luarocks.org/manifests/cdbattags/lua-resty-jwt-0.2.3-0.src.rock -o /tmp/lua-resty-jwt-0.2.3-0.src.rock
RUN curl -fSL https://luarocks.org/manifests/grafi/lunajson-1.2.3-1.src.rock -o /tmp/lunajson-1.2.3-1.src.rock
RUN curl -fSL https://luarocks.org/manifests/hanszandbelt/lua-resty-openidc-1.6.1-1.src.rock -o /tmp/lua-resty-openidc-1.6.1-1.src.rock

RUN luarocks install /tmp/luaossl-20250929-0.src.rock \
    OPENSSL_DIR=/usr \
    CRYPTO_DIR=/usr \
    LUA_INCDIR=/usr/local/openresty/luajit/include/luajit-2.1 && \
    rm /tmp/luaossl-20250929-0.src.rock
RUN luarocks install --pin /tmp/lua-resty-jwt-0.2.3-0.src.rock
# RUN luarocks install kong-oidc -- deprecated
RUN luarocks install /tmp/lunajson-1.2.3-1.src.rock
RUN luarocks install /tmp/lua-resty-openidc-1.6.1-1.src.rock
COPY ./luaplugins/oidc /plugins/oidc
WORKDIR /plugins/oidc
RUN luarocks make
COPY ./luaplugins/query-checker /plugins/query-checker
WORKDIR /plugins/query-checker
RUN luarocks make
COPY ./luaplugins/multi-tenancy /plugins/multi-tenancy
WORKDIR /plugins/multi-tenancy
RUN luarocks make
COPY ./luaplugins/rbac /plugins/rbac
WORKDIR /plugins/rbac
RUN luarocks make
COPY ./luaplugins/scope-checker /plugins/scope-checker
WORKDIR /plugins/scope-checker
RUN luarocks make
USER kong
