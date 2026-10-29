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

System Power is what the machine consumes, on battery as well as on mains. Battery Power is positive while charging and negative while discharging.

## Build and deploy

```sh
swift build -c release -Xswiftc -Osize
strip .build/release/mcenergy
codesign --force --sign "Developer ID Application" .build/release/mcenergy
install -m 755 .build/release/mcenergy ~/.local/bin/mcenergy
```

The same binary runs on every Apple Silicon Mac with a matching or newer macOS.
Use `install(1)` or `mv`, never `cp` over a running binary: macOS kills processes whose
executable was modified in place, including the next `mcenergy` invocation.

### Sign with a stable identity

The keychain grants access to the password per code signature. `swift build` signs ad hoc, and every
rebuild gets a new signature, so each deployed binary blocks on a keychain dialog on every Mac until
someone clicks "Always Allow" on that screen. Signing with the same identity every time avoids that:
after one approval, rebuilt binaries are trusted. Any identity works, including a self-signed one:

1. Keychain Access → Keychain Access menu → Certificate Assistant → Create a Certificate.
2. Name `mcenergy`, Identity Type "Self Signed Root", Certificate Type "Code Signing".
3. Sign with `codesign --force --sign mcenergy .build/release/mcenergy` after `strip`, never before:
   stripping discards the signature.

`security find-identity -v -p codesigning` lists the identities available for `--sign`. The target Macs
do not need the certificate; the signature travels inside the binary. The first start of a binary
signed with a new identity still needs one approval on each Mac, or a fresh `mcenergy install` there.

### Update running agents

```sh
scp .build/release/mcenergy spencer.local:.local/bin/mcenergy.new
ssh spencer.local 'mv ~/.local/bin/mcenergy.new ~/.local/bin/mcenergy && launchctl kickstart -k gui/$(id -u)/local.mcenergy'
ssh spencer.local 'tail -2 ~/Library/Logs/mcenergy.log'
```

A healthy restart logs `publishing <host> ...` followed by `connected to ...` within a few seconds.
A process that stays silent is waiting in the keychain read for a dialog on that Mac's screen.

Run `mcenergy install` from a terminal on the machine itself, not over SSH: an SSH session cannot
write to the login keychain ("User interaction is not allowed").

On first start macOS asks whether mcenergy may access the local network. The agent keeps waiting
(logging `waiting for network`) until the dialog is answered; allow it, or grant it later under
System Settings → Privacy & Security → Local Network.

## Use

```sh
mcenergy measure                       # one sample as the JSON Home Assistant receives (without the energy total)
mcenergy channels                      # raw IOReport channels, for diagnosing a new chip
mcenergy run --broker 192.168.0.78 --user mac --password secret --interval 10
mcenergy install --broker 192.168.0.78 --user mac          # launchd agent at login, prompts for the password
mcenergy run --broker ha.example.net --tls --user mac      # TLS on port 8883; the broker certificate must be trusted
mcenergy uninstall
mcenergy completion zsh > ~/.zfunc/_mcenergy
```

### Password handling

`install` stores the password in the login keychain (service `mcenergy`, account `<user>@<broker>:<port>`)
and writes `~/Library/LaunchAgents/local.mcenergy.plist` without any secret. `run` looks for the password in this order:

1. `--password`
2. environment variable `MCENERGY_MQTT_PASSWORD`
3. login keychain

`install` without a password prompts for it on the terminal; prefer that over `--password`, which is visible in
`ps` and shell history. A password always needs `--user`, MQTT forbids one without a username.
`uninstall` removes the agent and the keychain item.
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
- Without `--tls` everything, including the password, crosses the network in plain text. Fine on a trusted LAN,
  otherwise enable TLS on the broker and pass `--tls`.
- When the broker rejects the credentials (CONNACK 4 or 5) the agent retries only every five minutes, so a wrong
  password cannot trip a broker lockout.
- `run` stops cleanly on SIGTERM or Ctrl-C: it publishes `offline` first so Home Assistant does not wait for the will.
