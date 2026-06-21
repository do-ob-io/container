#!/bin/sh
# Headless no-op `xdg-open` shim for the opencode container.
#
# opencode tries to open the web UI in a local browser (e.g.
# `xdg-open http://localhost:4096`). There is no browser/display in a container,
# and without this shim the spawn fails with ENOENT. Print the URL so it stays
# visible in the logs and exit cleanly; reach the UI from the host browser.
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *) echo "xdg-open (headless): $arg" ;;
  esac
done
exit 0
