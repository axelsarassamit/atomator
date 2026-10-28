# Independent deployment configuration

Source scripts are inert until a site is explicitly configured. No endpoint,
account, domain, monitoring destination or VPN connection is selected automatically.

1. Download the complete repository.
2. Run `python3 configure_site.py --schema > site-settings.json`.
3. Fill every replacement with your own domain, realm, account and addresses.
   Documentation addresses and `.invalid` names cannot be deployed.
4. Create a separate local bundle:
   `python3 configure_site.py --config site-settings.json --output /private/new-bundle`.
5. Install with `sudo bash /private/new-bundle/run-configured.sh quick_install.sh`.
6. Set `SSH_USER`, add your hosts, and independently verify SSH host keys in
   `/remote_tools/known_hosts` before starting fleet actions.

Creating a bundle makes no connections. Its private `.site-settings.json` retains
only the explicit replacement map for future source updates. SSH/domain passwords
are not generated or added by the configurator. Do not put passwords in the map.
The manifest records SHA-256 checksums of the deployable code and documentation.

All current fleet scripts share credential parsing and SSH options. `SSH_PASSWORD`
is the preferred optional password variable; `SSH_PASS` remains an authentication
alias. SSH keys or an agent are supported. Credentials are parsed as data, never
sourced as code. Administrative actions use `sudo -n`; configure privilege policy
independently. Unknown or changed SSH host keys are rejected.

Do not commit local settings, credentials, host inventories, verified keys, reports
or VPN profiles. Shared deployment archives exclude runtime data and the private
replacement map. Configured source scripts can contain your site identifiers, so
keep configured bundles private as well. Supply `VPN_CONFIG_PATH` where required.
Legal terms and attribution files remain authoritative and are copied unchanged.

Updates and rollbacks use configured directory bundles, not raw installer downloads.
Installed code is staged and validated before activation, existing runtime data is
preserved, and previous installations remain in a private sibling backup directory.
Historical published archives and existing deployed systems are not modified by
creating a bundle. The destructive watchdog remains an explicitly selected operation;
its production payload and default timer have not changed.

See [README.md](README.md) for authentication, preview/retry options and migration.
