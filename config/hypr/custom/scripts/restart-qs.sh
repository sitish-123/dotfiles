#!/usr/bin/env bash
pkill -x qs
sleep 1.5
exec qs -c ii > "$HOME/.cache/qs.log" 2>&1
