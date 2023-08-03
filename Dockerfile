ARG ALPINE_VERSION=3.18

FROM alpine:$ALPINE_VERSION
ARG VERSION=1.20.0

ADD patches/* /tmp/patches

# Inspiration from https://github.com/gmr/alpine-pgbouncer/blob/master/Dockerfile
# hadolint ignore=DL3003,DL3018
RUN \
  # security
  apk add -U --no-cache --upgrade busybox ca-certificates && \
  # Download
  apk add -U --no-cache autoconf automake build-base curl libevent libevent-dev libtool make openssl openssl-dev pkgconfig postgresql-client && \
  curl -sv "http://www.microsoft.com/pkiops/certs/Microsoft%20Azure%20TLS%20Issuing%20CA%2002%20-%20xsign.crt" \
    | openssl x509 > /usr/local/share/ca-certificates/azure_ca_tls02.pem && \
  update-ca-certificates && \
  curl -o  /tmp/pgbouncer-$VERSION.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz && \
  cd /tmp && \
  # Unpack, compile
  tar xvfz /tmp/pgbouncer-$VERSION.tar.gz && \
  cd pgbouncer-$VERSION && \
  find /tmp/patches -type f -print0 | xargs -I{} -0 sh -c "patch -p0 < '{}'"&& \
  cat src/sbuf.c && \
  ./configure --prefix=/usr --enable-cassert --enable-werror && \
  make -j 4 && \
  # Manual install
  cp pgbouncer /usr/bin && \
  mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && \
  # entrypoint installs the configuration, allow to write as postgres user
  cp etc/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.example && \
  cp etc/userlist.txt /etc/pgbouncer/userlist.txt.example && \
  touch /etc/pgbouncer/userlist.txt && \
  (getent passwd postgres || adduser -DS postgres) && \
  chown -R postgres /var/run/pgbouncer /etc/pgbouncer && \
  # Cleanup
  cd /tmp && \
  rm -rf /tmp/pgbouncer*  && \
  apk del --purge autoconf automake curl build-base libevent-dev libtool make openssl-dev pkgconfig

COPY entrypoint.sh /entrypoint.sh
USER postgres
EXPOSE 5432
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
