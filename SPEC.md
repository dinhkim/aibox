# cbox Specification

This document defines the architecture, data model, and extension points of `cbox`. Use it as the reference when adding new tools, CLI options, or container behaviors.

---

## 1. Overview

`cbox` is a thin Rust CLI that wraps `container run` (Docker / Apple Container) to launch AI coding tools inside an isolated container. It handles:

- CLI parsing
- Tool validation & default selection
- Configuration file loading (`.cbxrc`)
- `container run` command assembly (volumes, env vars, image, workdir)
- Forwarding stdin/stdout/stderr and exit codes

---

## 2. Project Layout

```
.
├── Cargo.toml        # Binary name: cbx, depends on clap (derive)
├── src/
│   └── main.rs       # Entire application logic
└── README.md
```

---

## 3. Data Structures

### 3.1 CLI Args (`Args`)

Parsed by **clap** with derive macros.

| Field    | Type           | CLI Flag | Description                                      |
|----------|----------------|----------|--------------------------------------------------|
| `tool`   | `Option<String>` | (positional) | AI tool to run. Optional — falls back to config default |
| `workdir`| `Option<PathBuf>`| `-w`, `--workdir` | Host directory mounted to `/workspace`. Defaults to CWD |
| `image`  | `Option<String>` | `-i`, `--image` | Override the default container image               |
| `env`    | `Vec<String>`    | `-e`, `--env` | Repeatable env vars passed into the container      |

```rust
#[derive(Parser, Debug)]
#[command(name = "cbx")]
#[command(version = "1.0.0")]
struct Args {
    tool: Option<String>,

    #[arg(short = 'w', long = "workdir")]
    workdir: Option<PathBuf>,

    #[arg(short = 'i', long = "image")]
    image: Option<String>,

    #[arg(short = 'e', long = "env")]
    env: Vec<String>,
}
```

### 3.2 Runtime Config (`Config`)

Loaded from `.cbxrc` files (shell-like `KEY=VALUE` format).

| Field          | Type             | Source Key         | Description                  |
|----------------|------------------|--------------------|------------------------------|
| `default_tool` | `Option<String>` | `CBX_DEFAULT_TOOL` | Fallback when no positional arg |

```rust
struct Config {
    default_tool: Option<String>,
}
```

---

## 4. Tool Registry

Tools are registered in two compile-time constants and one match expression.

### 4.1 Constants

```rust
const DEFAULT_TOOL: &str = "opencode";
const TOOL_NAMES: &[&str] = &["opencode", "kilocode", "pi"];
```

- `DEFAULT_TOOL`: Used when no tool is specified and no config default exists.
- `TOOL_NAMES`: Authority list for validation.

### 4.2 Image Mapping

```rust
fn get_docker_image(tool: &str) -> String {
    match tool {
        "opencode" => "ghcr.io/anomalyco/opencode:latest".to_string(),
        "kilocode" => "ghcr.io/kilo-org/kilo:latest".to_string(),
        "pi"       => "pi-dev:latest".to_string(),
        _ => { /* exit 1 */ }
    }
}
```

### 4.3 Adding a New Tool

To add a tool (example: `aider`):

1. Append the tool name to `TOOL_NAMES`:
   ```rust
   const TOOL_NAMES: &[&str] = &["opencode", "kilocode", "pi", "aider"];
   ```

2. Add an image arm to `get_docker_image`:
   ```rust
   "aider" => "ghcr.io/some-org/aider:latest".to_string(),
   ```

3. **Optional** — Add tool-specific volume mounts or env vars in `main()` (see §6).

---

## 5. Configuration File Format

`cbox` reads two `.cbxrc` files in order (later overrides earlier):

1. `$HOME/.cbxrc`
2. `./.cbxrc` (current working directory)

### 5.1 Syntax

- Lines beginning with `#` are comments.
- Empty lines are ignored.
- Optional `export ` prefix is stripped.
- Values may be quoted with `"` or `'` (quotes are stripped).
- Only recognized keys have an effect; unknown keys are silently ignored.

Example:

```bash
# ~/.cbxrc
export CBX_DEFAULT_TOOL="kilocode"
```

### 5.2 Recognized Keys

| Key                | Scope    | Description                |
|--------------------|----------|----------------------------|
| `CBX_DEFAULT_TOOL` | runtime  | Default tool when omitted  |

---

## 6. Container Invocation

### 6.1 Base Command

The runtime constructs:

```bash
container run -it --rm \
  -v <workdir>:/workspace \
  -w /workspace \
  -e AI_BOX=true \
  [-e <extra_env> ...] \
  [tool-specific mounts ...] \
  <image>
```

### 6.2 Workdir Resolution Rules

| Input (`-w`) | Resolved Path                                 |
|--------------|-----------------------------------------------|
| omitted      | `std::env::current_dir()`                     |
| absolute     | used as-is                                    |
| relative     | `current_dir().join(input)`                   |

If the resolved path is not a directory, the program exits with code `1`.

### 6.3 Tool-Specific Overrides: `pi`

When `tool_name == "pi"`, extra host volumes are appended *before* the image argument:

| Host Path                              | Container Path                              | Purpose                  |
|----------------------------------------|---------------------------------------------|--------------------------|
| `$HOME/.pi/agent/models.json`          | `/home/piuser/.pi/agent/models.json`        | Pi model configuration   |
| `$HOME/.pi/agent/auth.json`            | `/home/piuser/.pi/agent/auth.json`          | Pi authentication        |
| `$HOME/.local/share/gopass`            | `/home/piuser/.local/share/gopass`          | gopass store             |
| `$HOME/.config/gopass/age`             | `/home/piuser/.config/gopass/age`           | gopass age keys          |

**To add similar special handling for a new tool**, insert a conditional block in `main()` before `cmd.arg(image)`:

```rust
if tool_name == "newtool" {
    let home = env::var("HOME").expect("HOME environment variable not set");
    let home = PathBuf::from(home);
    cmd.arg("-v").arg(format!("{}:/path/in/container", home.join(".newtool").display()));
}
```

---

## 7. Execution & Exit Behavior

1. `cmd.stdin(Stdio::inherit()).stdout(Stdio::inherit()).stderr(Stdio::inherit())`
2. `cmd.status()` is called. On spawn failure → print error and exit `1`.
3. The process exits with the container's exit code (`status.code().unwrap_or(1)`).

---

## 8. Error Handling Conventions

| Scenario                          | Behavior                                    |
|-----------------------------------|---------------------------------------------|
| No tool specified, no default     | `eprintln!("Error: No tool specified...")` → exit `1` |
| Invalid tool                      | `eprintln!("Error: Invalid tool...")` → exit `1` |
| Workdir does not exist            | `eprintln!("Error: Workdir does not exist...")` → exit `1` |
| `container run` spawn failure     | `eprintln!("Error: Failed to execute...")` → exit `1` |
| `.cbxrc` read failure             | Warning printed to stderr, execution continues |

---

## 9. Extension Checklist

Use this checklist when modifying `cbox`.

### Add a New Supported Tool
- [ ] Append to `TOOL_NAMES`
- [ ] Add image mapping in `get_docker_image`
- [ ] Add any tool-specific volume mounts in `main()`
- [ ] Update `README.md` usage examples and supported-tools table

### Add a New CLI Option
- [ ] Add field to `Args` struct with clap attributes
- [ ] Consume the field in `main()` and wire it into the `Command` builder
- [ ] Update `README.md` Options section

### Add a New Config Key
- [ ] Add field to `Config` struct
- [ ] Parse the key in `parse_config_file`
- [ ] Consume the config value in `main()` or `load_config()`
- [ ] Document the key in this spec and `README.md`

---

## 10. Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `clap` | `4.5` (derive feature) | CLI argument parsing |

No async runtime, no external HTTP clients — `cbox` shells out to the host `container` binary.
