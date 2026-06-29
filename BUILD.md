# Build Guide

This repository builds a native Raspberry Pi/Linux application called `sbitx`.
It is not a Node, Python, or container project.

## What gets built

- Main binary: `./sbitx`
- FT8 codec objects compiled from `ft8_lib/`
- SQLite logbook database: `data/sbitx.db` on first build

The main build is defined in [Makefile](./Makefile) and [build](./build).

## Supported environment

The codebase is written for Raspberry Pi on Linux and depends on:

- `gcc`
- `make`
- `pkg-config`
- `sqlite3`
- GTK 3 development headers
- ALSA development headers
- FFTW3 and FFTW3f
- `wiringPi`
- `ncurses`
- `pthread`

The current workspace where this guide was prepared is Windows, so the build was reviewed from source and scripts rather than executed locally.

## System dependencies

The repository's documented dependency flow is in [install.txt](./install.txt). The short version is:

```bash
./install-toolchain.sh --check
```

That script installs the native compiler toolchain, GTK/ALSA/SQLite/FFTW development packages, and `wiringPi` on Raspberry Pi systems.

You can also install packages manually:

```bash
sudo apt-get install ncurses-dev
sudo apt-get install libasound2-dev
sudo apt-get install libgtk-3-dev
sudo apt-get install libgtk+-3-dev
sudo apt-get install libsqlite3-dev
sudo apt-get install sqlite3
sudo apt-get install ntp ntpstat
```

Additional required setup:

- Install `wiringPi`
- Install FFTW3 and FFTW3f
- Enable the `snd-aloop` ALSA loopback module
- Configure the Pi audio overlay in `/boot/config.txt`

Those hardware and OS provisioning steps are covered in [DEPLOY.md](./DEPLOY.md).

## Build commands

### Main application

Use either command:

```bash
make
```

or:

```bash
./build sbitx
```

For WSL or non-Pi development without `wiringPi`, use dev mode:

```bash
make DEV_MODE=1
```

or:

```bash
DEV_MODE=1 ./build sbitx
```

Dev mode uses a local compatibility shim under `devshim/` so the code can compile without Raspberry Pi GPIO libraries. It is intended for desktop compilation and code navigation, not for hardware access.

The FT8 objects are compiled from source instead of linking the checked-in `ft8_lib/libft8.a`, since that archive may have been built on a different architecture.

What the build does:

- creates `audio/`, `data/`, and `web/` if needed
- creates `data/sbitx.db` from `data/create_db.sql` if it is missing
- links the `sbitx` binary against GTK3, ALSA, FFTW3, SQLite3, `wiringPi`, and the locally compiled FT8 objects

### FT8 library

The repo already includes `ft8_lib/libft8.a`, but if it needs to be rebuilt:

```bash
cd ft8_lib
make all
make install
```

`make install` builds `libft8.a` and installs it to `/usr/lib/libft8.a`.

### FT8 tests

```bash
cd ft8_lib
make run_tests
```

## Runtime expectations

Running the binary requires more than a successful compile. The program expects:

- Raspberry Pi GPIO access
- ALSA devices configured
- `snd-aloop` available
- hardware-specific config files in `data/`
- Pi-oriented filesystem paths such as `/home/pi/sbitx`

Examples of hard-coded runtime paths exist in:

- [sbitx.c](./sbitx.c)
- [sbitx_gtk.c](./sbitx_gtk.c)
- [fft_filter.c](./fft_filter.c)

Because of those assumptions, a successful build in an arbitrary directory does not guarantee a fully working runtime outside the normal Pi install layout.

## First run

From the repository root:

```bash
./sbitx
```

The application starts:

- the GTK UI
- the embedded web server on port `8080`
- the remote/telnet server on port `8081`

## Troubleshooting

### `ft8_lib/libft8.a` has the wrong architecture

The main repository build does not require the archive. If you need the archive for standalone FT8 tools, rebuild it on the target machine:

```bash
cd ft8_lib
make all
make install
```

### `pkg-config` or GTK headers missing

Install GTK 3 development packages and confirm:

```bash
pkg-config --cflags gtk+-3.0
pkg-config --libs gtk+-3.0
```

### `sqlite3` missing

Install:

```bash
sudo apt-get install sqlite3 libsqlite3-dev
```

### App starts but runtime features fail

That usually means the Pi provisioning steps are incomplete. Check:

- `snd-aloop`
- `/boot/config.txt`
- `hw_settings.ini`
- port `80` to `8080` redirect
- installation path under `/home/pi/sbitx`

### GPS time sync

If you want a USB GPS to set Linux system time and the DS3231 RTC used by sBitx:

1. Install GPS userspace tools:

```bash
sudo apt-get install gpsd gpsd-clients chrony
```

2. Confirm the GPS is producing UTC through `gpsd`:

```bash
gpspipe -w -n 10
```

3. Run the helper as root:

```bash
sudo ./sync-gps-time.sh
```

That script sets the Linux system UTC clock from GPS and, if sBitx is running on `127.0.0.1:8081`, sends the new `rtcsync` command so the app copies system UTC into the DS3231 RTC and refreshes its internal time source.

You can also refresh the RTC from the current Linux system time manually inside sBitx with:

```text
\rtcsync
```
