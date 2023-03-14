#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
exec elvish $SCRIPT_DIR/xfiles.elv "$@"
