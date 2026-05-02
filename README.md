# aibox 📦

A wrapper script that launches AI coding assistants (opencode, kilocode, pi) inside a container for a safer, isolated environment.

---

## Why aibox?

AI coding tools are powerful — but they can read files, run commands, and make changes outside your project. `aibox` sandboxes them inside container so you get the productivity benefits without the risk of unintended side effects on your host system.

---

## Features

- 🐳 Runs AI coding tools inside a container
- 🔒 Isolates tool execution from your host environment
- 🛠️ Supports **opencode**, **kilocode**, and **pi**
- 📁 Mounts your project directory into the container automatically
- ⚡ Simple drop-in replacement for running tools directly

---

## Requirements

- Any container engine, e.g. docker, apple container
- Bash (Linux / macOS / WSL)

---

## Installation

```bash
git clone https://github.com/yourusername/aibox.git
cd aibox
chmod +x aibox.sh

# Optionally, add to your PATH
ln -s "$(pwd)/aibox.sh" /usr/local/bin/aibox
```

---

## Usage

```bash
# Run opencode in a container
aibox opencode

# Run kilocode in a container
aibox kilocode

# Run pi in a container
aibox pi
```

By default, aibox mounts the current working directory into the container as the project workspace.

```bash
# Run from your project directory
cd ~/my-project
aibox opencode
```

### Options

```
Usage: aibox [OPTIONS] <tool>

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

You can configure defaults in a `.aiboxrc` file in your home directory or project root:

```bash
# ~/.aiboxrc
AIBOX_DEFAULT_TOOL=opencode
```

Environment variables (e.g. API keys) can be passed through with `-e`:

```bash
aibox -e OPENAI_API_KEY=$OPENAI_API_KEY opencode
```

---

## How It Works

`aibox` wraps a `docker run` command that:

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