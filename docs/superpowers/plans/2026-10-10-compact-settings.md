# Compact Settings Implementation Plan

> Execute inline with superpowers:executing-plans; verify each task before proceeding.

**Goal:** Replace the long settings form with compact category pages and native application list editing.

**Architecture:** Keep the existing settings bindings and persistence. A four-category sidebar selects the visible form. A reusable application list resolves icons and names from bundle identifiers, accepts application bundles through a picker or drop, and retains identifier entry as an advanced fallback.

**Tech Stack:** Swift 6, SwiftUI, AppKit; no new dependencies.

**Design:** User-approved sidebar: General, Lid & Power (initial page), Apps, Network. Consistent 680 × 480 window; detailed explanations and specialized controls in disclosure groups. App rows show icons; + opens a multi-application picker; Finder application drops add entries.

## Constraints

- Preserve settings persistence, Keychain behavior, permission handling, and recovery behavior.
- Preserve menu bar space in all states per AGENTS.md.
- Never launch dropped applications; read bundle metadata only.
- Retain unresolved bundle identifiers and display a generic icon.
- Do not change closed-lid sleep policy until its session behavior is clarified.

## Tasks

1. Test and implement application-bundle validation, duplicate handling, and a reusable list with icons, picker, drops, and advanced identifier entry.
2. Refactor SettingsView into four pages, move app lists to Apps, collapse explanatory copy and tmux controls, and constrain the settings window.
3. Run application-list, settings, and UI tests; build the application and verify its signature; review the complete diff and push changes to the fork.

## Review focus

- Invalid files, missing identifiers, duplicate bundles, and multiple dropped files.
- Bundle identifiers for apps absent from the machine.
- Same identifier selected from multiple copies of an app.
- Save and permission callbacks when changing pages.
- Long app lists and explanatory text within the fixed window.
