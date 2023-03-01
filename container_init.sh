#!/bin/bash

echo "booting msmtpd container..."
echo "writing configuration file..."

TZ=${TZ:-UTC}

# From https://github.com/docker-library/mariadb/blob/master/docker-entrypoint.sh#L21-L41
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

if [ -z "$SMTP_HOST" ]; then
  >&2 echo "ERROR: SMTP_HOST must be defined"
  exit 1
fi

echo "Creating configuration..."
cat > /etc/msmtprc <<EOL
account default
logfile -
syslog off
host ${SMTP_HOST}
EOL

file_env 'SMTP_USER'
file_env 'SMTP_PASSWORD'
if [ -n "$SMTP_PORT" ];                     then echo "port $SMTP_PORT" >> /etc/msmtprc; fi
if [ -n "$SMTP_TLS" ];                      then echo "tls $SMTP_TLS" >> /etc/msmtprc; fi
if [ -n "$SMTP_STARTTLS" ];                 then echo "tls_starttls $SMTP_STARTTLS" >> /etc/msmtprc; fi
if [ -n "$SMTP_TLS_CHECKCERT" ];            then echo "tls_certcheck $SMTP_TLS_CHECKCERT" >> /etc/msmtprc; fi
if [ -n "$SMTP_AUTH" ];                     then echo "auth $SMTP_AUTH" >> /etc/msmtprc; fi
if [ -n "$SMTP_USER" ];                     then echo "user $SMTP_USER" >> /etc/msmtprc; fi
if [ -n "$SMTP_PASSWORD" ];                 then echo "password $SMTP_PASSWORD" >> /etc/msmtprc; fi
if [ -n "$SMTP_DOMAIN" ];                   then echo "domain $SMTP_DOMAIN" >> /etc/msmtprc; fi
if [ -n "$SMTP_FROM" ];                     then echo "from $SMTP_FROM" >> /etc/msmtprc; fi
if [ -n "$SMTP_SET_FROM_HEADER" ];          then echo "set_from_header $SMTP_SET_FROM_HEADER" >> /etc/msmtprc; fi
if [ -n "$SMTP_SET_DATE_HEADER" ];          then echo "set_date_header $SMTP_SET_DATE_HEADER" >> /etc/msmtprc; fi
if [ -n "$SMTP_REMOVE_BCC_HEADERS" ];       then echo "remove_bcc_headers $SMTP_REMOVE_BCC_HEADERS" >> /etc/msmtprc; fi
if [ -n "$SMTP_UNDISCLOSED_RECIPIENTS" ];   then echo "undisclosed_recipients $SMTP_UNDISCLOSED_RECIPIENTS" >> /etc/msmtprc; fi
if [ -n "$SMTP_DSN_NOTIFY" ];               then echo "dsn_notify $SMTP_DSN_NOTIFY" >> /etc/msmtprc; fi
if [ -n "$SMTP_DSN_RETURN" ];               then echo "dsn_return $SMTP_DSN_RETURN" >> /etc/msmtprc; fi
unset SMTP_USER
unset SMTP_PASSWORD

### Start the binary here:
echo "starting msmtpd"
/usr/bin/msmtpd --interface=0.0.0.0 --port=2500 --command="/usr/bin/msmtp -f %F"