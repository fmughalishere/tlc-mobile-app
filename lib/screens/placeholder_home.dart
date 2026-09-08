// This file is empty on purpose.
//
// It used to hold the first-run proof-of-life screen. That job now belongs to
// lib/screens/diagnostics_screen.dart, which is reachable from Profile →
// Connection check and does the same three things properly: shows the session,
// shows the build, and calls every endpoint the app depends on.
//
// It is blank rather than deleted because the bridge that writes these files
// onto the machine can create and overwrite but cannot remove. Safe to delete
// by hand.
