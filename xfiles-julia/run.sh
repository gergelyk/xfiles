#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
exec julia $SCRIPT_DIR/src/xfiles.jl -- "$@"
