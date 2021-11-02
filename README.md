# Configurator

Configurator manages runtime configuration of services by reading data from AWS AppConfig and AWS SecretsManager, rendering ERB templates with that data, and then restarting systemd services to apply configuration updates.

## Usage
Configurator requires two pieces of meta configuration to start
- A configuration directory in $CONFIGURATION_DIRECTORY or passed in with -c/--configuration-directory
- A runtime directory in $RUNTIME_DIRECTORY or passed in with -r/--runtime-directory

Configurator will read all and apply files ending in .conf in the configuration directory in lexical order to configure itself.

Configuration files are in YAML. Configurator will read the following keys:

log_level: # One of debug, info, notice, warn, error. Defaults to info.
refresh_interval: # Number of seconds between each configuration source poll. Defaults to 5
