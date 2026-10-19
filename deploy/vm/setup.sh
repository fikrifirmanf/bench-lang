#!/usr/bin/env bash
# Prepare a small Ubuntu VM (2 vCPU / 2 GB, x86_64) as the `small-vm` benchmark runner.
#
#   sudo REPO_URL=https://github.com/<you>/bench-lang RUNNER_TOKEN=<token> ./setup.sh
#
# RUNNER_TOKEN comes from the repository: Settings > Actions > Runners > New self-hosted runner.
# It expires after an hour. Without REPO_URL and RUNNER_TOKEN the script prepares the machine only.
#
# What it does:
#   1. installs Docker, git and Python
#   2. adds 2 GB of swap as a safety net for the OS (benchmark containers are capped and never swap)
#   3. pins system services to CPU 0 so CPU 1 stays quiet for single-thread benchmarks
#   4. installs the GitHub Actions runner as a service with the label `small-vm`
set -euo pipefail

RUNNER_USER=bench
RUNNER_DIR=/opt/actions-runner

log() { printf '\n==> %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi
if [ "$(uname -m)" != "x86_64" ]; then
  echo "This VM is $(uname -m). CI builds x86_64 programs, so the VM must be x86_64 too." >&2
  exit 1
fi

log "Installing Docker, git and Python"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io git python3 python3-venv curl jq ca-certificates >/dev/null
systemctl enable --now docker

log "Adding swap"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -q -w vm.swappiness=10
echo 'vm.swappiness=10' > /etc/sysctl.d/90-bench.conf

log "Pinning system services to CPU 0"
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/90-bench-cpu.conf <<'EOF'
[Manager]
# Services (including dockerd and the runner) stay on CPU 0. Benchmark containers are placed on
# CPU 1 explicitly through --cpuset-cpus, so single-thread results are not disturbed by the OS.
CPUAffinity=0
EOF
systemctl daemon-reexec

log "Creating the $RUNNER_USER user"
id "$RUNNER_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$RUNNER_USER"
usermod -aG docker "$RUNNER_USER"

if [ -z "${REPO_URL:-}" ] || [ -z "${RUNNER_TOKEN:-}" ]; then
  log "Machine ready. Set REPO_URL and RUNNER_TOKEN and run again to install the runner."
  exit 0
fi

log "Installing the GitHub Actions runner"
release=$(curl -fsSL --max-time 30 https://api.github.com/repos/actions/runner/releases/latest)
version=$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")
archive="actions-runner-linux-x64-${version}.tar.gz"
expected=$(jq -r '.body' <<<"$release" | sed -n 's/.*<!-- BEGIN SHA linux-x64 -->\([0-9a-f]\{64\}\)<!-- END SHA linux-x64 -->.*/\1/p')
if [ -z "$expected" ]; then
  echo "Could not read the runner checksum from the release notes; stopping." >&2
  exit 1
fi
mkdir -p "$RUNNER_DIR"
curl -fsSL --max-time 300 -o "/tmp/$archive" "https://github.com/actions/runner/releases/download/v${version}/${archive}"
echo "$expected  /tmp/$archive" | sha256sum -c -
tar -xzf "/tmp/$archive" -C "$RUNNER_DIR"
rm -f "/tmp/$archive"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

sudo -u "$RUNNER_USER" "$RUNNER_DIR/config.sh" --unattended \
  --url "$REPO_URL" --token "$RUNNER_TOKEN" \
  --name "small-vm-$(hostname)" --labels small-vm --replace
(cd "$RUNNER_DIR" && ./svc.sh install "$RUNNER_USER" && ./svc.sh start)

log "Done. Set the repository variable SMALL_VM_ENABLED=true to start using this runner."
