#!/bin/sh
set -e

chown -R bitcoin .
exec gosu bitcoin "$@"
