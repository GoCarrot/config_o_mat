# Configurator

Configurator manages runtime configuration of services by reading data from AWS AppConfig and AWS SecretsManager, rendering ERB templates with that data, and then restarting systemd services to apply configuration updates.
