FROM kong:latest

LABEL description="Alpine + Kong  + kong-oidc plugin + LUA Plugins" 
# Install the js-pluginserver
USER root
# RUN apk add --update nodejs npm python3 make g++ && rm -rf /var/cache/apk/*
# RUN npm install --unsafe -g kong-pdk@0.5.3

ENV term xterm
RUN apk add --update vim nano

RUN apk update && apk add curl git gcc musl-dev
RUN luarocks install luaossl OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong
RUN luarocks install --pin lua-resty-jwt
RUN luarocks install kong-oidc
RUN luarocks install lunajson

COPY ./luaplugins/query-checker /plugins/query-checker
WORKDIR /plugins/query-checker
RUN luarocks make

COPY ./luaplugins/multi-tenancy /plugins/multi-tenancy
WORKDIR /plugins/multi-tenancy
RUN luarocks make

COPY ./luaplugins/rbac /plugins/rbac
WORKDIR /plugins/rbac
RUN luarocks make

USER kong
