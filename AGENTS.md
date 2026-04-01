# AGENTS.md

Specialized agent instructions for working on this repository.

## Agent: PowerShell Script Changes

When modifying any `.ps1` file:

1. **Test PS 5.1 compatibility** — never use PS 7+ only features without a fallback:
   - No `Get-Process .Parent` (use `Get-CimInstance Win32_Process`)
   - No `ConvertFrom-Json -AsHashtable` (use `PSCustomObject`)
   - No `??` null-coalescing or `?.` null-conditional operators
   - No `[type]::new()` ternary — use `if/else` assignment
2. **Preserve the try/catch pattern** in `show-toast.ps1`: inner try for WinRT (PS 5.1), catch falls back to BurntToast Submit (PS 7+), outer catch falls back to basic `New-BurntToastNotification`
3. **Never remove Win32 API fallback methods** in `claude-focus.ps1` — all three methods (AttachThreadInput, TopMost flash, AppActivate) are needed because Windows restricts `SetForegroundWindow` differently in different contexts

## Agent: Hook Configuration Changes

When modifying `config/hooks.json`:

1. Hook commands are **single-line PowerShell** — no line breaks inside the command string
2. All paths must use `$env:USERPROFILE\.claude\` (the installed location, not the repo)
3. Each hook must read stdin via `[System.IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.Encoding]::UTF8)` — this is how Claude Code passes data to hooks
4. The `shell` must be `"powershell"` (not `"pwsh"`) to match Claude Code's hook execution
5. Always include a catch block with a hardcoded fallback notification

## Agent: Install/Uninstall Script Changes

When modifying `install.ps1` or `uninstall.ps1`:

1. **Idempotency is sacred** — the script must be safe to run multiple times
2. **Always backup** `settings.json` before any modification (timestamped `.bak`)
3. **Merge hooks, never replace** — detect existing hooks by matching `show-toast.ps1` in command
4. **Preserve user settings** — only touch the `hooks` key, leave everything else intact
5. The installer must work when run from any directory (use `$MyInvocation.MyCommand.Path` for script-relative paths)

## Agent: CI/Release Changes

When modifying `.github/workflows/`:

1. CI must run on `windows-latest` (PowerShell syntax checking needs Windows)
2. Release runs on `ubuntu-latest` (just zipping and uploading, no PS needed)
3. Release is triggered only by `v*` tags — never on branch pushes
4. The zip bundle must include: `install.ps1`, `uninstall.ps1`, `src/`, `config/`, `assets/`, `README.md`, `LICENSE`, `CHANGELOG.md`
5. Use `softprops/action-gh-release@v2` with `generate_release_notes: true`
