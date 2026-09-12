# mcenergy

Records the power consumption of Apple Silicon Macs in Home Assistant via MQTT discovery.
No root, no third-party dependencies: one Swift binary reads IOKit and IOReport and publishes every few seconds.

## Sensors

| Entity | Source | Update rate | Machines |
|---|---|---|---|
| System Power, Adapter Loss, Battery Power | `AppleSmartBattery` power telemetry | PMU refreshes about once a minute | all |
| Energy (kWh, `total_increasing`) | System Power integrated over time, persisted in `~/Library/Application Support/mcenergy/energy.json` | every sample | all |
| CPU, GPU, Neural Engine, Memory, SoC Power | IOReport "Energy Model" counters | real time | all |
| Battery Level, Cycles, Charging, External Power, Adapter Rated Power | `AppleSmartBattery` | every sample | with battery |

Battery Power is positive while charging and negative while discharging.

## Build and deploy

```sh
swift build -c release
install -m 755 .build/release/mcenergy ~/.local/bin/mcenergy
```

The same binary runs on every Apple Silicon Mac with a matching or newer macOS.
Use `install(1)` or `mv`, never `cp` over a running binary: macOS kills processes whose
executable was modified in place, including the next `mcenergy` invocation.

Run `mcenergy install` from a terminal on the machine itself, not over SSH: an SSH session cannot
write to the login keychain ("User interaction is not allowed").

On first start macOS asks whether mcenergy may access the local network. The agent keeps waiting
(logging `waiting for network`) until the dialog is answered; allow it, or grant it later under
System Settings → Privacy & Security → Local Network.

## Use

```sh
mcenergy measure                       # one sample as the JSON Home Assistant receives
mcenergy channels                      # raw IOReport channels, for diagnosing a new chip
mcenergy run --broker 192.168.0.78 --user mac --password secret --interval 10
mcenergy install --broker 192.168.0.78 --user mac --password secret   # launchd agent at login
mcenergy uninstall
mcenergy completion zsh > ~/.zfunc/_mcenergy
```

### Password handling

`install` stores the password in the login keychain (service `mcenergy`, account `<user>@<broker>:<port>`)
and writes `~/Library/LaunchAgents/local.mcenergy.plist` without any secret. `run` looks for the password in this order:

1. `--password`
2. environment variable `MCENERGY_MQTT_PASSWORD`
3. login keychain

`install` without a password prompts for it on the terminal. `uninstall` removes the agent and the keychain item.
The agent logs to `~/Library/Logs/mcenergy.log`. After rebuilding the binary, run `install` again: it replaces the
keychain item, so the new binary can read it without an access prompt.

## Home Assistant

Requires the Mosquitto broker add-on and the MQTT integration. Each Mac appears as one device
named after its hostname with all entities above. Topics:

```
homeassistant/<component>/mcenergy_<host>/<key>/config   discovery, retained
mcenergy/<host>/state                                    JSON with all values
mcenergy/<host>/status                                   online / offline (last will)
```

## Notes

- IOReport is a private Apple library. It has been stable across many macOS releases and is what
  `powermetrics` uses, but Apple gives no guarantees.
- Energy counting skips gaps longer than five minutes (sleep, downtime) rather than extrapolating.
