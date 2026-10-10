# Menu bar space

Menu bar space is scarce and valuable. Preserve it whenever possible: make
Insomnia as narrow as practical in every state, including idle, timer entry,
starting, running, extending, and errors.

Use the minimum padding, gaps, and control widths needed for legibility and
reliable interaction. Avoid empty space and unnecessarily wide input fields.
Check the total status-item width across states when changing the UI, and keep
typing and animations from introducing unnecessary width changes. Preserve
readable values, accessible labels, and usable click targets while tightening
the layout.

## Settings UI

Use native SwiftUI components and their system styling for settings: navigation,
forms, sections, lists, toggles, disclosure groups, buttons, and file importers.
Let macOS own the window chrome and materials. Do not add custom glass backdrops,
card styling, or replacements for standard controls.

## GUI tests

UIStatusTests and UIStartupTests create real menu bar items and keyboard-focus
panels. Run them in an isolated macOS session, not on an active user desktop.
Use the noninteractive settings, application-bundle and menu-model tests for
routine local checks.
