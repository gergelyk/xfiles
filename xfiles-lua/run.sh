#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
exec lua5.4 $SCRIPT_DIR/xfiles.lua "$@"
