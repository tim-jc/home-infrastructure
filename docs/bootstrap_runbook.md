# Bootstrap `home-prod`

Use this runbook to prepare a freshly flashed Raspberry Pi 4 as the `home-prod`
Docker host. The bootstrap provisions the operating system and host directories
only; it does not deploy Homebridge or any other workload.

## 1. Flash Raspberry Pi OS

Use Raspberry Pi Imager to install Raspberry Pi OS Lite (64-bit). In the Imager
customisation settings:

- Set the hostname to `home-prod`.
- Create the intended administrative user.
- Configure SSH key authentication.
- Configure networking, locale, and timezone as required.

Boot the Pi and wait for it to become reachable.

## 2. Connect over SSH

From the administration computer:

```bash
ssh tim@home-prod.local
```

Replace `tim` if a different administrative username was configured.

After intentionally reflashing the host, its SSH host key will change. Remove
only the stale entries that apply before reconnecting:

```bash
ssh-keygen -R home-prod
ssh-keygen -R home-prod.local
ssh-keygen -R 192.168.1.94
```

Verify the new host-key fingerprint through a trusted channel before accepting
it. The IP-address entry is needed only if that address is still assigned to
`home-prod`.

## 3. Install Git and clone the repository

On `home-prod`:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates git
cd "$HOME"
git clone https://github.com/tim-jc/home-infrastructure.git
cd home-infrastructure
```

## 4. Run the bootstrap

Run the orchestrator as the administrative user, not from a root shell:

```bash
./scripts/bootstrap.sh
```

The script performs these stages in order and stops if any stage fails:

1. Update package metadata and fully upgrade the OS.
2. Install the required host utilities.
3. Install and validate Docker Engine, Buildx, and Compose.
4. Create and validate the canonical directories under `/srv/services`.

The stages are safe to rerun after a failure. If execution must occur from a
root shell, explicitly identify the administrative account:

```bash
BOOTSTRAP_USER=tim ./scripts/bootstrap.sh
```

## 5. Reboot and reconnect

If the bootstrap reports that a reboot is required, reboot the host:

```bash
sudo reboot
```

Reconnect after the host returns. A new login session is also required before
new Docker group membership takes effect.

## 6. Verify the host

Run the following as the administrative user:

```bash
docker info >/dev/null
docker buildx version
docker compose version
systemctl is-enabled docker
systemctl is-active docker
stat -c '%U:%G %a %n' \
  /srv/services \
  /srv/services/compose \
  /srv/services/config \
  /srv/services/data \
  /srv/services/logs
```

Docker should be available without `sudo`, its service should be `enabled` and
`active`, and each service directory should be owned by the administrative user
and their primary group with mode `750`.

The host is now ready for workload deployment through the repository's separate
application layer.
