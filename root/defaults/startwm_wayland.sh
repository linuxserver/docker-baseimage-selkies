#!/usr/bin/env bash
# selkies-session

ulimit -c 0
if [ "${PELORUS,,}" == "true" ]; then
  /usr/libexec/at-spi2-registryd &
fi
exec sleep infinity
