# Project baseline: wrapper, JDK, Maven config, .editorconfig

**Docs:** [Maven Wrapper](https://maven.apache.org/tools/wrapper/)
· [Enforcer rules](https://maven.apache.org/enforcer/enforcer-rules/)
· [SDKMAN usage](https://sdkman.io/usage/) · [SDKMAN install](https://sdkman.io/install/)
· [EditorConfig](https://editorconfig.org/)

One-time files that make the build work with no setup, on the right JDK, with consistent
whitespace. In a multi-module build every file here lives at the **reactor root** only.

## Contents

- Maven wrapper
- Pinned JDK
- SDKMAN
- .mvn/maven.config
- .editorconfig

## Maven wrapper

**Present when:** `mvnw`, `mvnw.cmd`, and `.mvn/wrapper/maven-wrapper.properties` exist and
`distributionUrl` names a concrete Maven version.

**Apply:**

```text
mvn wrapper:wrapper -Dmaven=<version>
```

- Pick the Maven version the project already targets (Enforcer `requireMavenVersion`, CI image);
  otherwise the current 3.9.x release from Maven Central.
- The default type `only-script` adds only `mvnw`, `mvnw.cmd`, and
  `.mvn/wrapper/maven-wrapper.properties` — no jar to commit.
- Keep `mvnw` executable in git: `git update-index --chmod=+x mvnw`.
- Run it from the reactor root.

## Pinned JDK

**Present when:** `maven.compiler.release` is set, the build rejects the wrong JDK (Enforcer
`requireJavaVersion`), and the JDK is pinned for developers (`.sdkmanrc` or a toolchains setup).

**Apply:**

- `maven.compiler.release` = the project's target version (never raise it as a side effect).
- Enforcer with **only** a `requireJavaVersion` rule matching the project's JDK (the JDK in
  `.sdkmanrc`, not a newer one):

  ```xml
  <requireJavaVersion><version>[17,)</version></requireJavaVersion>
  ```

  The other Enforcer rules (`requirePluginVersions`, `dependencyConvergence`, …) can turn an
  existing build red; they belong to the tooling area (the `java-maven` skill's
  `references/build-hardening.md`, Maven Enforcer section).
- `.sdkmanrc` at the root, created with `sdk env init` and edited to the project's JDK:

  ```text
  # Enable auto-env through the sdkman_auto_env config
  java=21.0.4-tem
  ```

  Use an identifier from `sdk list java`; match the vendor CI uses where known.

## SDKMAN

`sdk` is a shell function, so `command -v sdk` misses it. Detect SDKMAN with `~/.sdkman` or
`$SDKMAN_DIR`. If it's missing, **recommend it in the hand-back; never install it** (the installer
edits shell profiles):

```text
curl -s "https://get.sdkman.io" | bash        # or | zsh
source "$HOME/.sdkman/bin/sdkman-init.sh"     # or open a new terminal
sdk env install                               # installs the JDK named in .sdkmanrc
```

Then `sdkman_auto_env=true` in `~/.sdkman/etc/config` (or `sdk config`) switches the JDK on `cd`.

Windows: SDKMAN needs WSL (or Git Bash with MinGW, with known issues); it does not run in native
PowerShell or Cygwin. Say so instead of recommending it there.

## .mvn/maven.config

One option per line, nothing machine-specific (no local repo paths, no credentials):

```text
-ntp
```

`-ntp` drops download-progress lines from every build. Don't put `-q` here — people want normal
output; agents add `-q` on the command line (AGENTS.md says so).

## .editorconfig

Whitespace basics only. It is **not** a formatter: no `ij_java_*` or other IDE-specific keys, and
it never triggers a mass reformat.

**Infer, don't impose.** For each file type, sample existing files and use the most common
leading-space width (count lines that start with spaces; take the smallest common step). Use 4 for
a type with no files yet.

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space

[*.java]
indent_size = 4

[{pom.xml,*.xml}]
indent_size = 4

[*.{yml,yaml,json}]
indent_size = 2

[*.properties]
indent_size = 4

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab

[*.{bat,cmd}]
end_of_line = crlf
```

The values above are an example; write what the measurement found. Existing violations (tabs,
CRLF, trailing whitespace) are **reported**, never fixed in bulk — editors apply the rules only to
lines people touch.
