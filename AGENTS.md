# AGENTS.md

## Project Scope
- Repository purpose: OSDCloud-based EDU deployment automation.
- Primary language: PowerShell.
- Start with [README.md](README.md) for the high-level summary.

## Key Deployment Flow
- Pre-OS launcher: [StartURL-Dev-01.ps1](StartURL-Dev-01.ps1)
- First-boot orchestrator: [SetupComplete.ps1](SetupComplete.ps1)
- SetupComplete bridge: [SetupComplete.cmd](SetupComplete.cmd)
- First-boot update installer: [Install-LCU.ps1](Install-LCU.ps1)
- Build and language option data: [EDU.csv](EDU.csv), [OSLanguage.csv](OSLanguage.csv)

## Existing Custom Agent
- Use [osdcloud-powershell.agent.md](.github/agents/osdcloud-powershell.agent.md) for OSDCloud deployment scripting tasks.

## Agent Working Rules
- Prefer minimal, targeted edits in the nearest script on the execution path.
- Preserve deployment-safe behavior: keep allowlist/path validation for downloaded script sources unless explicitly asked to change it.
- Do not run imaging or reboot-triggering scripts unless the user explicitly requests execution.
- Treat changes under `C:\Windows\Setup\Scripts` and `C:\OSDCloud\Scripts\SetupComplete` as machine-impacting.
- Keep logs/transcript behavior intact unless the task is specifically about logging.

## Validation Commands (Safe By Default)
- Parse-check scripts after edits:
  - `pwsh -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('StartURL-Dev-01.ps1',[ref]$null,[ref]$errors) | Out-Null; if ($errors) { $errors | Format-Table -AutoSize; exit 1 }"`
  - Repeat for changed `.ps1` files.
- Use focused review instead of full deployment runs when possible.

## Practical Notes
- These scripts download content from GitHub raw URLs; prefer explicit URL/path checks before invocation.
- `StartURL-Dev-01.ps1` stages post-OS scripts and injects local-account values into downloaded SetupComplete content.
- `SetupComplete.ps1` performs post-setup tasks and ends with forced reboot behavior.
