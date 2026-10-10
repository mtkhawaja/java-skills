# Code intelligence: jdtls and IntelliJ

**Docs:** [Code intelligence plugins](https://code.claude.com/docs/en/plugins/code-intelligence#install-a-code-intelligence-plugin)
· [jdtls-lsp plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/jdtls-lsp)
· [Eclipse JDT.LS](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
· [JetBrains IDEs](https://code.claude.com/docs/en/jetbrains)

With the `jdtls-lsp` plugin, Claude sees compile errors right after its own edits and navigates
by symbol instead of text search. It is set up per machine, so the skill mostly **tells the user**
what to do. The only project change is optional.

## Contents

- Tell the user
- Per-platform binary install
- IntelliJ: /ide
- Project side

## Tell the user

1. **JDK for jdtls itself:** current jdtls releases need Java 21+ (a JDK, not a JRE) on `PATH` or
   in `JAVA_HOME` — independent of the JDK the project builds with. (The plugin README says 17+;
   follow the newer upstream requirement.)
2. **Install the `jdtls` binary** for their platform (below).
3. **Check it's on the `PATH` of the shell that starts `claude`:** `which jdtls`, or
   `Get-Command jdtls` in PowerShell.
4. **Install the plugin** at the Claude Code prompt:

   ```text
   /plugin install jdtls-lsp@claude-plugins-official
   ```

   Then `/reload-plugins` or start a new session.
5. **Confirm:** after Claude edits a `.java` file, a `Found N new diagnostic issues` line appears
   under the edit. If it never does, `/plugin` → **Errors** shows
   `Executable not found in $PATH: "jdtls"` when the binary isn't visible.

Code intelligence doesn't run in cloud sessions. jdtls indexes the project on first start and can
use a lot of memory on large reactors.

## Per-platform binary install

| Platform | Install |
| --- | --- |
| macOS | `brew install jdtls` |
| Arch Linux | `yay -S jdtls` (AUR) |
| Other Linux | Download a build from <https://download.eclipse.org/jdtls/milestones/>, extract to e.g. `~/.local/share/jdtls`, and symlink its `bin/jdtls` into a `PATH` directory (`ln -s ~/.local/share/jdtls/bin/jdtls ~/.local/bin/jdtls`). The launcher is a Python script: needs Python 3.9+. |
| Windows | Prefer **WSL** and follow the Linux steps there, running `claude` inside WSL. Natively, the download ships only the Python launcher (no `.exe`); a `.bat` wrapper on `PATH` may not be started by Claude Code. If they try it anyway, point them at the troubleshooting section of the code-intelligence docs. |

## IntelliJ: /ide

If the user works in IntelliJ, also tell them to connect Claude Code to it: run `claude` from
IntelliJ's terminal, or run `/ide` in an external terminal (it installs the Claude Code plugin if
it's missing, then asks to restart the IDE). Claude can then read IntelliJ's inspection results
through its `getDiagnostics` tool — inspections jdtls doesn't have.

The two complement each other: jdtls reports errors after every edit on its own, while IDE
diagnostics arrive only when Claude asks for them. Recommend jdtls either way.

## Project side

With the user's OK, enable the plugin for everyone in the repository by merging this into
`.claude/settings.json` (create the file if missing; never overwrite existing keys):

```json
{
  "enabledPlugins": {
    "jdtls-lsp@claude-plugins-official": true
  }
}
```

It doesn't install anything: each teammate still installs the binary and the plugin, and Claude
Code reports the plugin as not installed until they do. Add a "Code intelligence" pointer to
AGENTS.md (see `agent-docs.md`).
