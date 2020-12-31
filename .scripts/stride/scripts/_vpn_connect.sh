#!/bin/bash

while connection="$1"; shift; do
  osascript <<EOF
   tell application "Viscosity" to connect "${connection}"
EOF
done
