# cbox 📦

A Rust cli that launches any tools inside a container for a safer, isolated environment.

---

## Why cbox?

AI coding tools are powerful — but they can read files, run commands, and make changes outside your project. `cbox` sandboxes them inside container so you get the productivity benefits without the risk of unintended side effects on your host system.

---

## Features

- 🐳 Runs any tools inside a container
- 🔒 Isolates tool execution from your host environment
- 🛠️ Supports AI coding tools: **opencode**, **kilocode**, and **pi**
- 📁 Mounts your project directory into the container automatically
- ⚡ Simple drop-in replacement for running tools directly

---

## Requirements

- A supported container engine: docker, apple container

---

## Installation

TBD

---

## Usage

```bash
# Run opencode in a container
cbox opencode

# Run kilocode in a container
cbox kilocode

# Run pi in a container
cbox pi
```

By default, cbox mounts the current working directory into the container as the project workspace.

```bash
# Run from your project directory
cd ~/my-project
cbox opencode
```

### Options

```
Usage: cbox [OPTIONS] <tool>

Arguments:
  tool          AI coding tool to run: opencode | kilocode | pi

Options:
  -w, --workdir PATH    Project directory to mount (default: current directory)
  -i, --image IMAGE     Custom Docker image to use
  -e, --env KEY=VALUE   Pass environment variable into container (repeatable)
  -h, --help            Show this help message
```

---

## Configuration

You can configure defaults in a `.cboxrc` file in your home directory or project root:

```bash
# ~/.cboxrc
CBOX_DEFAULT_TOOL=opencode
```

Environment variables (e.g. API keys) can be passed through with `-e`:

```bash
cbx -e OPENAI_API_KEY=$OPENAI_API_KEY opencode
```

---

## How It Works

`cbox` wraps a `docker run` command that:

1. Pulls (or builds) a pre-configured container image with the AI tools installed
2. Mounts your current project directory to `/workspace` inside the container
3. Launches the selected tool inside the container
4. Cleans up the container on exit

The container has no access to the rest of your host filesystem unless you explicitly mount additional paths.

---

## Container image to use 

- opencode: `ghcr.io/anomalyco/opencode`
- kilocode: `ghcr.io/kilo-org/kilo`
- pi: [pi/Dockerfile](pi/Dockerfile)

---

## Supported Tools

| Tool | Description | Website |
|------|-------------|---------|
| [opencode](https://opencode.ai) | Terminal-based AI coding assistant | opencode.ai |
| [kilocode](https://kilocode.ai) | Terminal-based AI coding assistant | kilocode.ai |
| [pi](https://pi.dev) | Terminal-based AI coding assistant | pi.dev |

---

## Contributing

This is a personal hobby project — contributions, bug reports, and ideas are welcome! Feel free to open an issue or pull request.

---

## License

MIT