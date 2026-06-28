# Deploy Guide

This repository is deployed by building and running it directly on a Raspberry Pi.
There is no Docker image, cloud deploy target, or CI/CD pipeline in this repo.

## Deployment model

For this project, "deploy" means:

1. prepare the Raspberry Pi OS and hardware dependencies
2. clone or update the repository on the Pi
3. build `sbitx`
4. run it from the expected Pi filesystem layout
5. optionally replace an older `/home/pi/sbitx` installation

## Pi provisioning

The source-of-truth script and notes are:

- [install.txt](./install.txt)
- [setup-ap.sh](./setup-ap.sh)
- [install-toolchain.sh](./install-toolchain.sh)

### 1. Install base packages

For the compiler toolchain and core development libraries, the fastest path is:

```bash
./install-toolchain.sh --runtime --check
```

If you prefer to install each dependency manually, use the package commands below.

### 1a. Install base packages manually

```bash
sudo apt-get install ncurses-dev
sudo apt-get install libasound2-dev
sudo apt-get install libgtk-3-dev
sudo apt-get install libgtk+-3-dev
sudo apt-get install sqlite3
sudo apt-get install libsqlite3-dev
sudo apt-get install ntp
sudo apt-get install ntpstat
```

### 2. Install `wiringPi`

`wiringPi` is required by the GPIO and I2C code.

```bash
cd /tmp
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb
```

### 3. Install FFTW3

Both double and single precision builds are required:

```bash
./configure
make
sudo make install

./configure --enable-float
make
sudo make install
```

### 4. Enable ALSA loopback

The app expects `snd-aloop` for external digital-mode integrations.

Temporary:

```bash
sudo modprobe snd-aloop enable=1,1,1 index=1,2,3
```

Persist at boot by adding this to `/etc/rc.local`:

```bash
sudo modprobe snd-aloop enable=1,1,1 index=1,2,3
```

Verify with:

```bash
aplay -l
```

### 5. Configure `/boot/config.txt`

Append:

```txt
gpio=4,17,27,22,10,9,11,5,6,13,26,16,12,7,8,25,24=ip,pu
gpio=24,23=op,pu
avoid_warnings=1
dtoverlay=audioinjector-wm8731-audio
```

Disable onboard audio by changing:

```txt
#dtparam=audio=on
```

### 6. Disable PulseAudio client autospawn

In `/etc/pulse/client.conf`, add:

```txt
autospawn = no
daemon-binary = /bin/true
```

### 7. Redirect port 80 to the embedded web server

The application listens on port `8080`, while the docs expect port `80`.

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -I OUTPUT -p tcp -d 127.0.0.1 --dport 80 -j REDIRECT --to-ports 8080
sudo apt-get install iptables-persistent --fix-missing
```

### 8. Optional host naming

To make the Pi appear as `sbitx.local`:

```bash
sudo cp hosts /etc/hosts
sudo cp hostname /etc/hostname
```

## Wi-Fi access point setup

This version expects the Pi to expose a Wi-Fi AP for the front panel.

Run:

```bash
sudo ./setup-ap.sh
```

That script:

- installs `hostapd` and `dnsmasq`
- creates virtual interface `uap0` on top of `wlan0`
- configures AP IP `192.168.4.1`
- creates a `uap0.service` systemd unit
- enables and starts the AP services

Default AP settings from [setup-ap.sh](./setup-ap.sh):

- SSID: `zbitx`
- Password: `zbitx12345`
- Gateway: `192.168.4.1`

## Fresh install on a Pi

```bash
cd ~
mkdir -p sbitxv2
cd sbitxv2
git clone https://github.com/afarhan/zbitxv2.git
cd zbitxv2
make
sudo ./setup-ap.sh
```

If migrating from an older `sbitx` install, back up hardware settings first:

```bash
cp ~/sbitx/data/hw_settings.ini ~/sbitx/data/hw_settings.zbitxv1
```

Then add these values near the top of `~/sbitx/data/hw_settings.ini` as documented in [README.md](./README.md):

```txt
bfo_freq=40048000
hw=4
center_bin=600
```

## Running after deploy

From the repo root:

```bash
./sbitx
```

Helper launchers also exist:

- [start](./start)
- [start.sh](./start.sh)
- [sBitx.desktop](./sBitx.desktop)

## Updating an installed Pi

Two helper scripts exist:

- [update](./update)
- [update_zbitx](./update_zbitx)

They both assume the installed repo lives at `/home/pi/sbitx`, reset the remote to `https://github.com/afarhan/zbitxv2.git`, pull latest changes, and rebuild.

Equivalent manual flow:

```bash
cd /home/pi/sbitx
git remote set-url origin https://github.com/afarhan/zbitxv2.git
git pull
./build sbitx
```

`update_zbitx` also runs:

```bash
git checkout main
```

## Important path assumptions

The codebase is not fully relocatable. Runtime paths are hard-coded in several places under `/home/pi/sbitx`, including:

- settings files
- FFT wisdom files
- desktop icon paths
- temporary FT8 output

If you deploy somewhere else, expect to patch those paths or symlink into `/home/pi/sbitx`.

## Front panel firmware

For zbitx v1 hardware being upgraded to this v2 software model, the front panel firmware also needs to be updated. The repo README points to:

- <https://github.com/afarhan/zbitxv2_front_panel/blob/main/zbitx_front_panel_v2.ino.uf2>

## Smoke test checklist

After deployment, confirm:

- `./sbitx` launches without linker errors
- GTK UI opens on the Pi
- web UI responds on `http://127.0.0.1:8080`
- port `80` redirects correctly if configured
- `remote.c` server listens on `8081`
- `aplay -l` shows loopback devices
- front panel connects over the Pi AP
