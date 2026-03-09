# Kolibri

## Overview

Kolibri is an offline educational platform installed as a Python venv + systemd service.

- **Port**: 8080
- **Venv**: `/opt/kolibri-venv`
- **Data**: `/opt/kolibri-data`
- **Linux user**: `him`
- **Service**: `kolibri.service`

On first visit, Kolibri's setup wizard will guide you through creating an admin user and facility.

---

## Installing Channels

Use `kolibri-channels.sh` to download content from the internet (run on your master server):

```bash
curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/kolibri-channels.sh
sudo bash kolibri-channels.sh
```

Installs 37 English channels (Khan Academy, CK-12, PhET, TED-Ed, MIT Blossoms, OpenStax, etc.) and 15 Spanish channels. The script is idempotent — already-installed channels are skipped.

---

## Syncing Content to New Servers

Use `kolibri-sync.sh` to copy all content from a master server to a new server via rsync (no internet needed on the target):

```bash
# Run on the NEW server:
curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/kolibri-sync.sh
sudo bash kolibri-sync.sh <master-ip>

# Example:
sudo bash kolibri-sync.sh 10.0.1.102
```

This stops Kolibri, rsyncs `/opt/kolibri-data/` from the master, runs `scanforfiles` to register the content, then restarts Kolibri.

---

## Troubleshooting

**Kolibri service not starting:**
```bash
sudo systemctl status kolibri
sudo journalctl -u kolibri -n 50 --no-pager
```

**Kolibri starts but setup wizard appears (no admin user):**
```bash
# Re-run admin setup manually
sudo -u him KOLIBRI_HOME=/opt/kolibri-data /opt/kolibri-venv/bin/kolibri manage shell -- -c "
from kolibri.core.auth.models import Facility, FacilityUser
from kolibri.core.device.models import DevicePermissions
facility, _ = Facility.objects.get_or_create(name='HimEdu')
user, created = FacilityUser.objects.get_or_create(username='him', defaults={'facility': facility})
user.facility = facility
user.set_password('ABCD_1234')
user.save()
DevicePermissions.objects.update_or_create(user=user, defaults={'is_superuser': True, 'can_manage_content': True})
print('Done')
"
sudo systemctl restart kolibri
```

**Can't log in to Kolibri (wrong password):**
```bash
sudo systemctl stop kolibri
sudo -u him KOLIBRI_HOME=/opt/kolibri-data /opt/kolibri-venv/bin/kolibri manage changepassword him
sudo systemctl start kolibri
```

**Kolibri running on wrong port or not accessible:**
```bash
# Check what port it's listening on
sudo ss -tlnp | grep kolibri
# Should show 0.0.0.0:8080

# Check service config
cat /etc/systemd/system/kolibri.service
```

**Kolibri data directory permissions error:**
```bash
sudo chown -R him:him /opt/kolibri-data
sudo systemctl restart kolibri
```
