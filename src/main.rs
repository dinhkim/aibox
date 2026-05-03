use std::env;
use std::path::PathBuf;
use std::process::{Command, Stdio};

use clap::Parser;

const DEFAULT_TOOL: &str = "opencode";
const TOOL_NAMES: &[&str] = &["opencode", "kilocode", "pi"];

#[derive(Parser, Debug)]
#[command(name = "cbx")]
#[command(version = "1.0.0")]
struct Args {
    /// AI coding tool to run: opencode|kilocode|pi
    tool: Option<String>,

    /// Project directory to mount (default: current directory)
    #[arg(short = 'w', long = "workdir")]
    workdir: Option<PathBuf>,

    /// Custom container image to use
    #[arg(short = 'i', long = "image")]
    image: Option<String>,

    /// Pass environment variable into container (repeatable)
    #[arg(short = 'e', long = "env")]
    env: Vec<String>,
}

fn main() {
    let args = Args::parse();

    let tool_name = match args.tool {
        Some(t) => t,
        None => {
            let config = load_config();
            config.default_tool.unwrap_or_else(|| DEFAULT_TOOL.to_string())
        }
    };

    validate_tool(&tool_name);

    let workdir = match args.workdir {
        Some(w) => {
            if w.is_relative() {
                env::current_dir()
                    .expect("Failed to get current directory")
                    .join(w)
            } else {
                w
            }
        }
        None => env::current_dir().expect("Failed to get current directory"),
    };

    if !workdir.is_dir() {
        eprintln!("Error: Workdir does not exist: {}", workdir.display());
        std::process::exit(1);
    }

    let image = match args.image {
        Some(img) => img,
        None => get_docker_image(&tool_name),
    };

    println!("Running {} in container...", tool_name);

    let mut cmd = Command::new("container");
    cmd.arg("run")
        .arg("-it")
        .arg("--rm")
        .arg("-v")
        .arg(format!("{}:/workspace", workdir.display()))
        .arg("-w")
        .arg("/workspace");

    cmd.arg("-e").arg("AI_BOX=true");
    for env_var in &args.env {
        cmd.arg("-e").arg(env_var);
    }

    if tool_name == "pi" {
        let home = env::var("HOME").expect("HOME environment variable not set");
        let home = PathBuf::from(home);
        cmd.arg("-v").arg(format!(
            "{}:/home/piuser/.pi/agent/models.json",
            home.join(".pi/agent/models.json").display()
        ));
        cmd.arg("-v").arg(format!(
            "{}:/home/piuser/.pi/agent/auth.json",
            home.join(".pi/agent/auth.json").display()
        ));
        cmd.arg("-v").arg(format!(
            "{}:/home/piuser/.local/share/gopass",
            home.join(".local/share/gopass").display()
        ));
        cmd.arg("-v").arg(format!(
            "{}:/home/piuser/.config/gopass/age",
            home.join(".config/gopass/age").display()
        ));
    }

    cmd.arg(image);

    cmd.stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    let status = cmd.status().unwrap_or_else(|e| {
        eprintln!("Error: Failed to execute 'container run': {}", e);
        std::process::exit(1);
    });

    std::process::exit(status.code().unwrap_or(1));
}

struct Config {
    default_tool: Option<String>,
}

fn load_config() -> Config {
    let mut config = Config { default_tool: None };

    if let Ok(home) = env::var("HOME") {
        let home_config = PathBuf::from(home).join(".cbxrc");
        if home_config.is_file() {
            parse_config_file(&home_config, &mut config);
        }
    }

    let local_config = PathBuf::from(".cbxrc");
    if local_config.is_file() {
        parse_config_file(&local_config, &mut config);
    }

    config
}

fn parse_config_file(path: &PathBuf, config: &mut Config) {
    let contents = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Warning: Failed to read {}: {}", path.display(), e);
            return;
        }
    };

    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let line = if let Some(stripped) = line.strip_prefix("export ") {
            stripped
        } else {
            line
        };

        if let Some((key, value)) = line.split_once('=') {
            let key = key.trim();
            let mut value = value.trim();

            if value.len() >= 2
                && ((value.starts_with('"') && value.ends_with('"'))
                    || (value.starts_with('\'') && value.ends_with('\'')))
            {
                value = &value[1..value.len() - 1];
            }

            if key == "CBX_DEFAULT_TOOL" {
                config.default_tool = Some(value.to_string());
            }
        }
    }
}

fn validate_tool(tool: &str) {
    if tool.is_empty() {
        eprintln!("Error: No tool specified. Use -h for help.");
        std::process::exit(1);
    }

    if !TOOL_NAMES.contains(&tool) {
        eprintln!(
            "Error: Invalid tool '{}'. Supported tools: {}",
            tool,
            TOOL_NAMES.join("|")
        );
        std::process::exit(1);
    }
}

fn get_docker_image(tool: &str) -> String {
    match tool {
        "opencode" => "ghcr.io/anomalyco/opencode:latest".to_string(),
        "kilocode" => "ghcr.io/kilo-org/kilo:latest".to_string(),
        "pi" => "pi-dev:latest".to_string(),
        _ => {
            eprintln!("Error: No image configured for tool '{}'", tool);
            std::process::exit(1);
        }
    }
}
