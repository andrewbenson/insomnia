# Native menu bar recovery

The app now uses SwiftUI's `MenuBarExtra` with `.window` style. The menu bar
label contains only the system eye symbol and a compact countdown (`5h59m`,
`59m`, then seconds below one minute).
The timer reserves enough monospaced text width for the session span so ordinary
ticks and unit changes do not alter the label's layout. SwiftUI renders the
label to a native template image with a fixed intrinsic size; width does not
depend on whether MenuBarExtra preserves Text modifiers. Clicking it
opens a system-owned popover with native duration text fields and explicit
Start, Add Time, and End Session buttons. Editing a duration does not change the
running session. End Session directly awaits the existing recovery operation.

The runtime no longer constructs `StatusItemController`, `KeyCatcherPanel`, or
its local/global mouse monitors. Those legacy sources remain for existing tests
and comparison, but are not part of the running interface. Settings opens through
SwiftUI's `openSettings` action and `Settings` scene, using the existing native
forms and controls. The session engine, journal, quit cleanup, and CLI recovery
entry point remain unchanged.

Before publishing, check the installed app on an actual desktop: start a short
session, edit each duration field without the popover collapsing, add time, end
the session and confirm the countdown disappears, then open Settings and quit.
Automated engine and offscreen layout tests cannot establish pointer behavior
in the system menu bar. The installed native popover was accepted by the user
before merging into the fork's main branch.
