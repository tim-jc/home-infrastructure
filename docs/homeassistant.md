# Home Assistant Container

## Architecture and scope

`home-prod` runs Home Assistant Container through Docker Compose.

- The generic host runtime root is `/srv/services`.
- The version-controlled Compose definition is
  `compose/homeassistant/compose.yaml`.
- Persistent Home Assistant state is stored outside Git at
  `/srv/services/data/homeassistant` and mounted at `/config`.
- The host bootstrap installs and validates Docker and creates only the generic
  `/srv/services` layout.
- `scripts/deploy/homeassistant.sh` deploys only Home Assistant.

The deployment script does not install Docker, perform onboarding, modify files
inside `/config`, configure integrations, or manage backup and restore.

The Compose service uses the stable Home Assistant image, host networking,
`unless-stopped` restart behaviour, and a 60-second stop grace period. It also
mounts the host timezone and D-Bus socket. `NET_ADMIN` and `NET_RAW` are
intentional requirements for Bluetooth operation.

## Image and upgrade policy

The default deployment is a reconciliation, not an upgrade:

```bash
./scripts/deploy/homeassistant.sh
```

It runs `docker compose up -d --pull missing`. On a fresh or recovered host,
Docker pulls `ghcr.io/home-assistant/home-assistant:stable` when no local image
is available. On an already deployed host, it reuses the local image. This
avoids silently advancing the mutable `stable` tag during an ordinary rerun.

An upgrade is explicit:

```bash
./scripts/deploy/homeassistant.sh --upgrade
```

Upgrade mode pulls the image referenced by the Compose definition and then
reconciles the container. Review Home Assistant release notes and ensure a
usable backup exists before using this mode. Backup design is intentionally not
part of the current repository.

## Initial deployment or recovery

After completing the host bootstrap, run from the repository as the
administrative user:

```bash
./scripts/deploy/homeassistant.sh
```

The script verifies Docker and Compose access, creates the state directory if
absent, checks its ownership and mode, validates the Compose definition, starts
the service, and confirms that its container is running.

If running from a root shell is unavoidable, explicitly identify the account
that should own the state directory:

```bash
DEPLOY_USER=tim ./scripts/deploy/homeassistant.sh
```

For disaster recovery, first bootstrap the fresh host and clone this repository.
Restore `/srv/services/data/homeassistant` through the future state-recovery
procedure, then run the deployment script. Git restores the workload definition;
it does not restore Home Assistant state. The repository does not yet define how
state is backed up, validated, transferred, or restored.

## Routine operations

Run these commands from the repository root:

```bash
# Status
docker compose -f compose/homeassistant/compose.yaml ps

# Follow logs
docker compose -f compose/homeassistant/compose.yaml logs --follow homeassistant

# Restart the existing container
docker compose -f compose/homeassistant/compose.yaml restart homeassistant

# Recreate using the already available image
docker compose -f compose/homeassistant/compose.yaml up -d --pull never --force-recreate homeassistant

# Reconcile repository configuration without an implicit upgrade
./scripts/deploy/homeassistant.sh
```

## Bluetooth

Home Assistant requires the read-only `/run/dbus` mount and the `NET_ADMIN` and
`NET_RAW` capabilities in the Compose definition for the intended Bluetooth
functionality.

During the first deployment, the Pi Bluetooth adapter was soft-blocked by
`rfkill`. It was unblocked manually:

```bash
sudo rfkill unblock bluetooth
```

Afterwards, `hci0` was powered and Home Assistant Bluetooth became healthy. A
complete host reboot confirmed that Bluetooth remained unblocked and powered.
The deployment script deliberately does not change host radio state. If
Bluetooth fails, inspect `rfkill list bluetooth` and the state of `hci0` before
changing the Compose definition.

## First-deployment acceptance tests

The initial production deployment established that:

- Home Assistant onboarding completed successfully.
- Home Assistant Bluetooth was healthy after clearing the rfkill soft block.
- Container restart completed successfully.
- Complete Raspberry Pi reboot completed successfully.
- Persistent configuration survived container recreation, container restart,
  and host reboot.
- Docker and Home Assistant started automatically after host reboot.
- Bluetooth remained unblocked and powered after host reboot.

## `/srv/services/compose`

The generic bootstrap currently creates `/srv/services/compose`, but active
Compose definitions live in Git and are executed directly from the repository.
No current Home Assistant workflow uses the runtime directory, so it appears
redundant. Do not remove it from an existing host automatically. A separate
bootstrap cleanup should first confirm that no other workloads or operational
procedures depend on it, then remove it from the canonical generic layout in an
intentional change.
