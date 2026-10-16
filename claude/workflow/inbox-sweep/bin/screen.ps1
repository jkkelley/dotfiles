# Full virtual-screen capture to a PNG: the completion proof for browser seats (inbox sweep R2 baseline, R7 final).
# Called by bin/sweep-proof.sh as: powershell.exe -NoProfile -ExecutionPolicy Bypass -File screen.ps1 -Out <windows path>
#
# Ported from the 2026-10-15 hand run's screen.ps1 (%USERPROFILE%\inbox-triage-20261015\screen.ps1), unchanged in
# behavior: System.Windows.Forms for the virtual screen bounds, System.Drawing to copy and save it.
#
# What broke (docs/design/inbox-sweep.md section 3):
#   F6 - closing the blank anchor tab that tabs_context_mcp creates dissolved the seat's tab group and orphaned its
#        working tab, so every later close failed with "Tab is not in Claude's tab group for this session".
#   F7 - a seat's own "tab closed" was taken as proof the tabs were gone; they were not.
# Why this script exists: only the Windows screen shows what Chrome really holds. tabs_context_mcp from another
# session cannot see a seat's group, and the seat's report is the claim being checked, so neither can be the proof.
# Why a whole-screen PNG and not a Chrome-only grab: the tab bar is the evidence, and a window grab would need the
# chrome.exe window handle, which is exactly what is unreliable when the group is orphaned.
# Cost: it captures whatever else is on the screen, so the PNG stays in <run>/proof and is pruned with the run.
param([Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
