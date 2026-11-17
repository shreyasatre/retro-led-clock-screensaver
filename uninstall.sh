#!/bin/bash
rm -rf "$HOME/Library/Screen Savers/Retro LED Clock.saver"
killall legacyScreenSaver 2>/dev/null || true
echo "Removed Retro LED Clock."
