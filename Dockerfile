# syntax=docker/dockerfile:1

ARG MSMTP_VERSION=1.8.22
ARG ALPINE_VERSION=3.17
ARG XX_VERSION=1.1.2

FROM tonistiigi/xx:${XX_VERSION} AS xx
FROM alpine:${ALPINE_VERSION} AS base
COPY --from=xx / /
RUN apk --update --no-cache add clang curl file make pkgconf tar xz
ARG MSMTP_VERSION
WORKDIR /src
RUN curl -sSL "https://marlam.de/msmtp/releases/msmtp-$MSMTP_VERSION.tar.xz" | tar xJv --strip 1

FROM base AS builder
ENV XX_CC_PREFER_LINKER=ld
ARG TARGETPLATFORM
RUN xx-apk --no-cache --no-scripts add g++ gettext-dev gnutls-dev libidn2-dev
RUN set -ex;CXX=xx-clang++ ./configure --host=$(xx-clang --print-target-triple) --prefix=/usr --sysconfdir=/etc --localstatedir=/var;make -j$(nproc);make install;xx-verify /usr/bin/msmtp;xx-verify /usr/bin/msmtpd;

FROM alpine:${ALPINE_VERSION}

#ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
#  TZ="UTC" \
#  PUID="1500" \
#  PGID="1500"

RUN apk --update --no-cache add \
    bash \
    ca-certificates \
    gettext \
    gnutls \
    libidn2 \
    libgsasl \
    libsecret \
    mailx \
    shadow \
    tzdata \
  && ln -sf /usr/bin/msmtp /usr/sbin/sendmail \
  && rm -rf /tmp/*

COPY container_init.sh /usr/bin/

COPY --from=builder /usr/bin/msmtp* /usr/bin/

EXPOSE 2500

RUN chmod +x /usr/bin/container_init.sh;touch /etc/msmtprc;chmod 775 /etc/msmtprc

CMD /usr/bin/container_init.sh

HEALTHCHECK --interval=10s --timeout=5s \
  CMD echo EHLO localhost | nc 127.0.0.1 2500 | grep 250 || exit 1
