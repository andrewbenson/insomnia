# Bundled application audit — October 10, 2026

The defaults are an upstream seed list, not an inventory of this Mac. Installed
applications were checked using their Info.plist metadata under /Applications,
~/Applications and /System/Applications. For absent apps, the links below are
current Homebrew cask definitions or vendor documentation. Cask evidence supports
an identifier but does not prove an application is installed here.

## All default entries

| Friendly name | Bundle identifier | Verification |
| --- | --- | --- |
| Slack | `com.tinyspeck.slackmacgap` | Installed |
| WhatsApp | `net.whatsapp.WhatsApp` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/w/whatsapp.rb) |
| Discord | `com.hnc.Discord` | Installed |
| T3 Code | `com.t3tools.t3code` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/t/t3-code.rb), now distributed as T3 Code (Alpha) |
| T3 Code (Reasoning) | `com.t3tools.t3code.reasoning` | Absent; current variant not independently verified |
| Conductor | `com.conductor.app` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/c/conductor.rb) |
| Terminal | `com.apple.Terminal` | Installed |
| iTerm2 | `com.googlecode.iterm2` | Installed |
| Ghostty | `com.mitchellh.ghostty` | Installed |
| Warp | `dev.warp.Warp-Stable` | Installed |
| Google Chrome | `com.google.Chrome` | Installed |
| Chromium | `org.chromium.Chromium` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/c/chromium.rb) |
| Arc | `company.thebrowser.Browser` | Installed |
| Docker Desktop | `com.docker.docker` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/d/docker-desktop.rb) |
| Visual Studio Code | `com.microsoft.VSCode` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/v/visual-studio-code.rb) |
| Cursor | `com.todesktop.230313mzl4w4u92` | Installed |
| Zed | `dev.zed.Zed` | Installed |
| Google Antigravity | `com.google.antigravity` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/a/antigravity.rb) |
| Claude | `com.anthropic.claudefordesktop` | Installed |
| ChatGPT | `com.openai.codex` | Installed; both local display and bundle names are ChatGPT |
| Tailscale | `io.tailscale.ipn.macsys` | Absent; [vendor documentation](https://tailscale.com/docs/integrations/mdm/mac) |
| LM Studio | `ai.elementlabs.lmstudio` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/l/lm-studio.rb) |
| Ollama | `com.electron.ollama` | Absent; [cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/o/ollama-app.rb) |

12 defaults are installed; 10 absent identifiers have current supporting evidence;
one absent variant remains unverified. Missing apps previously fell back to the
last identifier component, producing misleading names such as `macsys`, `docker`
and `lmstudio`. The UI now uses metadata when available, known friendly names
otherwise, a generic application icon, and a **Not installed** label.

## Built-in protections

The existing editor, terminal, browser, password-manager and infrastructure IDs
were checked against local installations where available and current cask
definitions otherwise. No clear erroneous identifier was found in those groups.
Comments marked “installed” describe upstream verification, not this machine.

Additional installed apps match the existing protection categories: OpenCode
(`ai.opencode.desktop`), Dia (`company.thebrowser.dia`), Termius
(`com.termius-dmg.mac`), WireGuard (`com.wireguard.macos`) and UTM (`com.utmapp.UTM`).
The fork adds these to automatic-pause protection, without silently changing
saved user lists. Tailscale's Mac App Store variant (`io.tailscale.ipn.macos`) is
also protected; its distinct identifier is documented by
[Tailscale](https://tailscale.com/docs/integrations/mdm/mac).

The Windsurf identifier `com.exafunction.windsurf` remains valid, though the
[current cask](https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/d/devin-desktop.rb)
calls the app Devin Desktop. Zoom and Granola were verified locally; current Teams
is supported by [Microsoft's deployment documentation](https://learn.microsoft.com/en-us/microsoftteams/new-teams-mac-install-prerequisites).

The T3 Reasoning variant, Otter (`com.otterai.desktop`), and the legacy Webex helper
IDs `com.cisco.washost`, `com.cisco.webexmeetingsapp` and `com.webex.pluginagent`
remain unverified against a current local installation or fresh primary evidence.
Their protections remain in place pending better evidence. Absence alone is not
grounds to remove a protection.

Slack, WhatsApp and Discord are explicitly paused by the default pause list.
That is a behavior choice, not a bundle-ID error: pausing them also pauses their
work and notifications while the lid is closed. Users can remove those entries
or add an app to Protected apps to exempt it.
