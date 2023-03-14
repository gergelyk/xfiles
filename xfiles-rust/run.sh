#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
exec $SCRIPT_DIR/target/debug/xfiles "$@"
