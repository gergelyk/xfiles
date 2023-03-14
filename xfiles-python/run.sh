#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
exec python3.8 $SCRIPT_DIR/xfiles "$@"
