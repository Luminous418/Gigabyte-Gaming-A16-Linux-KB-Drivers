# GG-A16_linuxdrivers

Linux support for the **GIGABYTE GAMING A16 (CTH)** laptop. Currently this
repo provides full control of the **RGB keyboard backlight**.

## The problem

On Linux the A16 keyboard backlight never turns on during a cold boot. The
only workaround is booting Windows first (which lights it up) and then
rebooting into Linux.

### Why

The A16 keyboard is a USB-HID device (VID `0414`, PID `8105`) and its
backlight is **not** exposed through `/sys/class/leds`. One of its HID
interfaces instead implements the standard Microsoft **HID LampArray**
protocol (Usage Page `0x59`, "Lighting and Illumination"):

```
$ xxd /sys/bus/hid/devices/0003:0414:8105.0008/report_descriptor | head
00000000  05 59 09 01 a1 01 85 01  ...
```

Backlight state is applied by *host software*: on Windows, Gigabyte Control
Center / GiMate sends the LampArray feature reports at startup, and the
keyboard keeps that state until it loses power. Linux sends nothing, so the
backlight stays off after a cold boot. The same situation exists on several
ASUS TUF/Vivobook A16 models (ITE5570 controller) and the fix is identical.

## Requirements

- Linux kernel with hidraw support (any modern kernel)
- `python3` (the tool only uses the standard library + `fcntl` ioctls)
- Your user account must be in the `input` group

## Installation

```bash
git clone https://github.com/Luminous418/Gigabyte-Gaming-A16-Linux-Drivers.git
cd Gigabyte-Gaming-A16-Linux-Drivers
sudo ./install.sh
```

`install.sh` will:

1. Copy `scripts/gigabyte-kbd` to `/usr/local/bin/gigabyte-kbd`
2. Install a udev rule granting `input`-group access to the keyboard's
   hidraw nodes (so you don't need root for day-to-day use)
3. Install a **user** systemd unit that restores the backlight at login
   (this fixes the cold-boot problem)
4. Install an optional resume hook for after suspend (`systemctl enable
   --now gigabyte-kbd-resume.service`)
5. Run a quick test

## Usage

```bash
gigabyte-kbd info                     # show lamp array attributes
gigabyte-kbd on                       # white, full brightness
gigabyte-kbd color ff0000             # red
gigabyte-kbd color 00ff00 --intensity 128   # green at half intensity
gigabyte-kbd off                      # turn off
gigabyte-kbd restore                  # re-apply last saved color
gigabyte-kbd auto                     # hand control back to the firmware
```

`color`, `on` and `off` save their value to
`~/.config/gigabyte-kbd.conf`, which `restore` uses on login.

## How it works

The tool talks to the LampArray hidraw node using the standard hidraw
ioctls (`HIDIOCSFEATURE` / `HIDIOCGFEATURE`). Report map decoded from the
device's report descriptor:

| Report ID | Usage            | Purpose                                |
|-----------|------------------|----------------------------------------|
| `0x01`    | LampArrayAttributes | read LampCount, kind, bounding box   |
| `0x05`    | LampRangeUpdate  | set a lamp range to one RGB + intensity |
| `0x06`    | LampArrayControl | AutonomousMode (0 = manual, 1 = auto)   |

A typical session does: disable AutonomousMode (take control from the
firmware), then send a `LampRangeUpdate` with the desired color and
intensity.

## Layout

```
scripts/gigabyte-kbd              the controller tool
udev/99-gigabyte-kbd.rules        hidraw access for the input group
systemd/gigabyte-kbd.service      user unit: restore at login
systemd/gigabyte-kbd-resume.service  optional system unit: restore after suspend
install.sh                        installer / test runner
```

## Long-term / upstream

- OpenRGB ≥ 0.9 does not yet implement HID LampArray (maintainers confirmed
  it is planned).
- A `hid-lamparray` kernel helper (single-zone RGB under
  `/sys/class/leds`) is in upstream discussion; once it lands and Solus
  enables `CONFIG_HID_LAMPARRAY`, sysfs control will work out of the box.
- If you add support for other Gigabyte A16/A16X SKUs, open a PR.

## License

MIT