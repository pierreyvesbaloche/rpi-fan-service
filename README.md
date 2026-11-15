# rpi-fan — Raspberry Pi fan & LED controller

Temperature-controlled cooling fan (PWM on GPIO18) plus 4 RGB LEDs (WS2812-style
bit-banging on GPIO17/GPIO4) that show a blue → green → yellow → red gradient
based on the CPU temperature. Runs as a systemd service (`rpi-fan`).

- **Fan**: off below 45 °C, then 65 % + 1.75 %/°C, capped at 100 %
- **LEDs**: 40 °C = blue → 55 °C = green → 65 °C = yellow → 70 °C = red
- **Service**: `Restart=always`, `RestartSec=10`; handles SIGTERM/SIGINT
  (turns the LEDs off and cleans up the GPIOs on shutdown)

## Hardware wiring (BCM numbering)

| Pin  | Function            |
|------|-------------------|
| 17   | LED data (MOSI)   |
| 4    | LED clock (SCLK)  |
| 18   | Fan (PWM, 100 Hz) |

## Requirements

- Raspberry Pi OS (Debian-based) with `python3`
- GPIO 17, 4 and 18 free (BCM numbering)

## Installing

```bash
git clone https://github.com/<your-org>/rpi-fan.git
cd rpi-fan
sudo ./install.sh
```

`install.sh` will:

1. `apt update` and install `python3-pip`, `python3-rpi.gpio`, `python3-venv`, `git`
2. Create `~/tools`
3. Create the virtual environment `~/rpi-fan-env` (`--system-site-packages`)
4. Copy `rpi-fan-custom.py` into `~/tools/`
5. Upgrade pip inside the virtual environment
6. Write `/etc/systemd/system/rpi-fan.service`, tailored to the calling
   user (correct `User=`, `WorkingDirectory=` and `ExecStart=` paths)
7. `systemctl daemon-reload` and start the `rpi-fan` service

The script is idempotent: you can re-run it safely.

## Managing the service

```bash
sudo systemctl status rpi-fan     # status
journalctl -u rpi-fan -f          # live logs
sudo systemctl stop rpi-fan       # stop
sudo systemctl start rpi-fan      # start
sudo systemctl disable rpi-fan    # don't start at boot (if you used enable)
```

## Uninstalling

```bash
sudo ./uninstall.sh
```

Stops/disables the service, removes the unit file and the daemon state,
then removes `~/tools/rpi-fan-custom.py` and the `~/rpi-fan-env`
virtual environment.

## Make

```
make install     # == sudo ./install.sh
make uninstall   # == sudo ./uninstall.sh
make check       # basic integrity checks
```

## Repository layout

| File                  | Purpose                                      |
|-----------------------|----------------------------------------------|
| `rpi-fan-custom.py`  | The fan + LED controller application         |
| `install.sh`         | Installer (root, `sudo ./install.sh`)        |
| `uninstall.sh`       | Uninstaller (root, `sudo ./uninstall.sh`)    |
| `Makefile`           | Convenience targets                           |
