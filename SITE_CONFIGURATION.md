# Independent deployment configuration

Source scripts do not run until a site is explicitly configured. No endpoint, account,
monitoring destination, domain join or VPN connection is selected automatically.

1. Run `python3 configure_site.py --schema > site-settings.json`.
2. Fill every replacement with your own domain, realm, account and destination addresses.
   `example.invalid` and `192.0.2.0/24` are inert documentation placeholders.
   Read each script before choosing which administrative operation to run.
3. Create a separate local bundle:
   `python3 configure_site.py --config site-settings.json --output /path/to/new-bundle`.
4. Run a selected operation with `/path/to/new-bundle/run-configured.sh script.sh`.
   Creating a bundle alone makes no network connections and changes no system configuration.

Supply any required SSH or domain password through the named environment variable at
runtime. Passwords are not shipped in source or written by the configurator. Legacy generated
SSH commands use `SSH_PASSWORD` for authentication and `sudo -n` for privilege elevation;
configure the remote account's sudo policy independently. No automatic privilege grant is added.
Do not commit local settings, credentials, host inventories or VPN profiles.

Provide your own `VPN_CONFIG_PATH` when using VPN setup; example files are never activated.
The repository no longer includes deployed VPN profiles or bundled deployment logs/backups.
Existing user installations, saved hosts, system credentials and historical releases are unchanged.
Legal terms and attribution files remain authoritative.

Update and rollback inputs must also be configured bundles. Raw downloads and pre-separation local updaters are not executed automatically. Historical published archives remain unchanged.
