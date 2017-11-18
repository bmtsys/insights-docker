FROM appcelerator/alpine:3.6.0

RUN apk --no-cache upgrade
RUN apk --no-cache add nodejs-current tini@community

ENV GRAFANA_VERSION 4.6.2

ENV GOLANG_VERSION 1.9.2
ENV GOLANG_SRC_URL https://storage.googleapis.com/golang/go$GOLANG_VERSION.src.tar.gz
ENV GOLANG_SRC_SHA256 665f184bf8ac89986cfd5a4460736976f60b57df6b320ad71ad4cef53bb143dc

RUN apk update && apk add fontconfig && \
    echo "Installing build dependencies" && \
    apk --virtual build-deps add build-base openssl go git gcc python musl-dev make nodejs-dev fontconfig-dev nodejs-current-npm patch && \
    echo "Installing Go" && \
    export GOROOT_BOOTSTRAP="$(go env GOROOT)" && \
    wget -q "$GOLANG_SRC_URL" -O golang.tar.gz && \
    echo "$GOLANG_SRC_SHA256  golang.tar.gz" | sha256sum -c - && \
    tar -C /usr/local -xzf golang.tar.gz && \
    rm golang.tar.gz && \
    cd /usr/local/go/src && \
    ./make.bash && \
    export GOPATH=/go && \
    export PATH=/usr/local/go/bin:$PATH && \
    go version && \
    npm install npm@latest -g && \
    npm --version && \
    mkdir -p $GOPATH/src/github.com/grafana && cd $GOPATH/src/github.com/grafana && \
    git clone https://github.com/grafana/grafana.git -b v${GRAFANA_VERSION} &&\
    cd grafana && \
    npm install -g yarn@0.27.5 && \
    npm install -g grunt-cli@1.2.0 && \
    go run build.go setup && \
    go run build.go build && \
    yarn install --pure-lockfile && \
    npm --version && \
    npm run build && \
    npm uninstall -g yarn && \
    npm uninstall -g grunt-cli && \
    npm cache --force clear && \
    mv ./bin/grafana-server ./bin/grafana-cli /bin/ && \
    mkdir -p /etc/grafana/json /var/lib/grafana/plugins /var/log/grafana /usr/share/grafana && \
    mv ./public /usr/share/grafana/public && \
    mv ./conf /usr/share/grafana/conf && \
    echo "Removing build dependencies" && \
    apk del build-deps && cd / && rm -rf /var/cache/apk/* /usr/local/share/.cache $GOPATH /usr/local/go /root/.npm /root/.node-gyp /root/.config /tmp/phantomjs /tmp/*compile-cache* /usr/lib/node_modules/npm

VOLUME ["/var/lib/grafana", "/var/lib/grafana/plugins", "/var/log/grafana"]

EXPOSE 3000

ENV INFLUXDB_HOST localhost
ENV INFLUXDB_PORT 8086
ENV INFLUXDB_PROTO http
ENV INFLUXDB_USER grafana
ENV INFLUXDB_PASS changeme
ENV GRAFANA_USER admin
ENV GRAFANA_PASS changeme
#ENV GRAFANA_BASE_URL
#ENV FORCE_HOSTNAME

COPY ./grafana.ini /usr/share/grafana/conf/defaults.ini.tpl
COPY ./run.sh /run.sh

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/run.sh"]

#HEALTHCHECK --interval=5s --retries=5 --timeout=2s CMD curl -u $GRAFANA_USER:$GRAFANA_PASS 127.0.0.1:3000/api/org 2>/dev/null | grep -q '"id":'
