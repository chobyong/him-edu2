# Configuration

Edit the variables at the top of `setup.sh` before running:

```bash
# WiFi Access Point
AP_SSID="him-edu"         # Network name clients will see
AP_PASSWORD="1234567890"  # WiFi password (min 8 characters)
AP_CHANNEL=6              # 2.4GHz channel (1-11)
AP_COUNTRY=US             # Regulatory country code
AP_IP="10.42.0.1"         # Gateway IP assigned to this server on WiFi

# NextCloud
NC_ADMIN_USER="him"       # Admin username
NC_ADMIN_PASS="ABCD_1234" # Admin password

# Kolibri
KOLIBRI_USER="him"              # Linux user that runs the Kolibri process
KOLIBRI_ADMIN_USER="him"        # Kolibri web login username
KOLIBRI_ADMIN_PASS="ABCD_1234"  # Kolibri web login password
KOLIBRI_FACILITY="HimEdu"       # School/facility name in Kolibri
```

All other values are auto-detected (WiFi interface name, wired IP address).
