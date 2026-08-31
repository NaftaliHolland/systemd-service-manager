# Systemd Service Manager

A simple interactive TUI for managing a predefined list of `systemd` services.

The script allows you to view service status, perform common service-management operations and follow logs without repeatedly typing `systemctl` or `journalctl` commands.

## Features

* View configured systemd services.
* Start and stop services.
* Restart services.
* Enable/Disable services.
* Follow logs

## Requirements

The script requires:

* A Linux system using **systemd**
* Bash
* `systemctl`
* `journalctl`
* `sudo` if running the script as a non-root user

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

Alternatively, if you don't want to install it system-wide, you could add an alias to your `~/.bashrc` to save yourself a few milliseconds of typing:

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
[f]   Follow logs 
[d]   Disable
[q]   Quit
```

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
| `f`       | Follow logs with journalctl        |
| `d`       | Disable the selected service       |
| `q`       | Quit                               |

Keys are case-insensitive where applicable.

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
