# Systemd Service Manager

A simple interactive terminal UI (TUI) for managing a predefined list of `systemd` services.

The script allows you to view service status and perform common service-management operations without repeatedly typing `systemctl` commands.

## Features

* View configured systemd services in a table.
* Display both:

  * **Enabled status** — whether the service starts automatically at boot.
  * **Active status** — whether the service is currently running.
* Start and stop services.
* Toggle a service between started and stopped states.
* Restart services.
* Enable services at boot.
* Disable services at boot.
* View detailed `systemctl status` output.
* Navigate using arrow keys or `j`/`k`.
* Automatically uses `sudo` when the script is not running as root.
* Supports a custom configuration file.
* Automatically creates a starter configuration if no configuration exists.

## Requirements

The script requires:

* A Linux system using **systemd**
* Bash
* `systemctl`
* `sudo` if running the script as a non-root user
* A terminal that supports ANSI escape sequences and `stty`

Most modern systemd-based Linux distributions should work.

## Installation

Clone or copy the script onto your system:

```bash
chmod +x service-manager.sh
```

You can then run it directly:

```bash
./service-manager.sh
```

For convenient system-wide use, you can optionally place it somewhere in your `PATH`:

```bash
sudo cp service-manager.sh /usr/local/bin/service-manager
sudo chmod +x /usr/local/bin/service-manager
```

You can then run:

```bash
service-manager
```

Alternatively, if you don't want to install it system-wide, you could add an alias to your ~/.bashrc to save yourself a few milliseconds of typing:

```bash
alias sm='/path/to/service-manager.sh'
```

Then reload your shell:

```bash
source ~/.bashrc
```

Now you can launch it with:

```bash
sm
```

## Configuration

The service list is read from a configuration file.

The script searches for a configuration file in the following order:

1. File specified with `-c` or `--config`
2. `$SERVICE_MANAGER_CONFIG` environment variable
3. `/etc/service-manager/services.conf`

The **first matching option is used**.

### Configuration format

The configuration file contains one systemd unit name per line.

For example:

```text
# services.conf

nginx.service
postgresql.service
redis.service
```

Blank lines and comments are ignored.

You can also use comments after a service name:

```text
nginx.service       # Web server
postgresql.service # Database
redis.service       # Cache
```

### Default configuration

If `/etc/service-manager/services.conf` does not exist and no other configuration is specified, the script automatically creates a starter configuration:

```text
/etc/service-manager/services.conf
```

The generated file contains commented examples:

```text
# service-manager services list
#
# One systemd unit name per line. Blank lines and lines starting with '#'
# are ignored.
#
# nginx.service
# postgresql.service
# redis.service
```

After editing the file, run the script again.

## Using a Custom Configuration

You can specify a configuration file using `-c`:

```bash
./service-manager.sh -c ./services.conf
```

or:

```bash
./service-manager.sh --config ./services.conf
```

This is useful when you want different service lists for different environments.

For example:

```bash
./service-manager.sh --config /opt/myapp/services.conf
```

## Environment Variable

Instead of passing the configuration file every time, you can set:

```bash
export SERVICE_MANAGER_CONFIG=/opt/myapp/services.conf
```

Then simply run:

```bash
./service-manager.sh
```

The environment variable is used when a configuration file was not explicitly provided using `-c` or `--config`.

## Command-Line Options

### `-c`, `--config`

Specify the configuration file:

```bash
./service-manager.sh --config /path/to/services.conf
```

### `-h`, `--help`

Display usage information:

```bash
./service-manager.sh --help
```

## Interface

When started, the service manager displays something similar to:

```text
========================================
        SYSTEMD SERVICE MANAGER
========================================

Service                   Enabled    Active
------------------------------------------------
> nginx.service           enabled    active
  postgresql.service      enabled    active
  redis.service           disabled   inactive


[↑/k]  Move up
[↓/j]  Move down
[Enter]  View status
[Space]  View status
[s]   Start / stop
[r]   Restart
[e]   Enable
[d]   Disable
[q]   Quit
```

The currently selected service is highlighted.

## Keyboard Controls

| Key       | Action                             |
| --------- | ---------------------------------- |
| `↑` / `k` | Move selection up                  |
| `↓` / `j` | Move selection down                |
| `Enter`   | View detailed service status       |
| `Space`   | View detailed service status       |
| `v`       | View detailed service status       |
| `s`       | Start or stop the selected service |
| `r`       | Restart the selected service       |
| `e`       | Enable the selected service        |
| `d`       | Disable the selected service       |
| `q`       | Quit                               |

Keys are case-insensitive where applicable.

## Service Actions

### Start / Stop

Press `s` to toggle the selected service.

If the service is currently active:

```text
systemctl stop <service>
```

If the service is not active:

```text
systemctl start <service>
```

For example:

```text
nginx.service → active
```

Pressing `s` stops it.

Pressing `s` again starts it.

### Restart

Press `r` to restart the selected service:

```bash
systemctl restart <service>
```

### Enable

Press `e` to enable the selected service:

```bash
systemctl enable <service>
```

Enabling a service configures it to start automatically according to its systemd configuration, commonly at boot.

### Disable

Press `d` to disable the selected service:

```bash
systemctl disable <service>
```

### View Status

Press `Enter`, `Space`, or `v` to view the normal systemd status output:

```bash
systemctl --no-pager status <service>
```

This is useful when you need more information than the main table provides, such as recent log messages or why a service failed.

## Permissions

The script can be run either as root or as a normal user.

### Running as root

```bash
sudo ./service-manager.sh
```

When running as root, service-management commands are executed directly.

### Running as a normal user

```bash
./service-manager.sh
```

The script automatically detects that it is not running as root and uses `sudo` for operations that change service state.

You may therefore be prompted for your password when performing actions such as:

* Start
* Stop
* Restart
* Enable
* Disable
