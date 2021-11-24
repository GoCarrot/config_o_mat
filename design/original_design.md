Configurator

Object Types:

Service -- A systemd service that is configured/managed by the configurator
ConfigurationProfile -- An AWS AppConfig configuration that the configurator retrieves
Template -- A template file that the configurator will use to generate an updated configuration file

Lifecycle:
OnBoot
  Each ConfigurationProfile will be loaded in declaration order. Once all ConfigurationProfiles are fully loaded, each Template will be evaluated. Once all Templates are evaluated, the configurator will go through each Service in declaration order and trigger a configuration update. Configuration updates are synchronus -- the configurator will not proceed to the next service until it has confirmed that configuration has been applied to the current service. If a service is not currently running then a configuration update will be considered successful immediately after updating configuration files.

ConfigurationProfileLoad
  The configuration profile will be loaded from AWS AppConfig. Any ancillary data defined by the loaded profile, e.g. secrets, will then be loaded. If any step fails the configurator will enter the OnPendingFailure state with the given ConfigurationProfile.

Every RefreshInterval
  Each ConfigurationProfile will be refreshed in declaration order. If a ConfigurationProfile is updated, Templates which reference that profile will be reevaluated. Once all such Templates are reevaluated, any which change will trigger configuration updates for any referencing Services in declaration order. All steps are synchronous, that is if a ConfigurationProfile has an update the configurator will _stop_ refreshing other profiles until all changes from the updated ConfigurationProfile have been successfully applied, and if multiple Services reference a Template each service must successfully complete its reload before the configurator will refresh the next Service.

ConfigurationUpdate
  Configuration updates are applied atomically. That is, if updating a single ConfigurationProfile modifies multiple Templates, the configurator will not apply changes until _all_ such Templates have been updated. Similarily if a modification to a Template requires multiple Services to be reloaded the configurator will not start reloading a Service until the prior Service reload is complete and successful. If any Service reload fails in the process of applying a ConfigurationUpdate, the source ConfigurationProfile will be considered to have failed and the configurator will
    1. Roll back the faulty ConfigurationProfile
    2. Perform a ConfigurationUpdate with the rolled back ConfigurationProfile
    3. In some way indicate failure such that AWS AppConfig can determine a course of action

OnPendingFailure
  If a ConfigurationUpdate fails, the configurator enters a "pending failure" state. When pending failure, the configurator will exclusively refresh the ConfigurationProfile which triggered the failed ConfigurationUpdate. If the ConfigurationProfile does not receive any updates (including a rollback by AWS AppConfig) within FailureTimeout, the configurator will itself enter a failure state and trigger its systemd OnFailure action. N.B. This may include systemd initiated restarts of the configurator.

State:
For each ConfigurationProfile the configurator will persistently store the most recently successfully applied version and the most recently retrieved version. If the configurator starts with state present, and any ConfigurationProfile has a retrieved version that does not equal its applied version, the configurator will immediately refresh the ConfigurationProfile from AWS AppConfig and proceed to ConfigurationUpdate for that ConfigurationProfile.

Service reload:
A Service may define one of the following ways to apply its updated configuration
- try-reload-or-restart
  This will use systemd to try-reload-or-restart the managed service. By default this will be considered successful if the try-reload-or-restart operation succeeds.
- flip-flpp
  This will use a custom script to manage an instantiated service unit with the instances @1 and @2. If both instances are running at the time of the reload, the configurator will enter OnPendingFailure. Otherwise the configurator will bring up the instance which is not currently running. By default if starting that instance succeeds then the configurator will stop the old instance and consider the reload successful.

A Service may also define additional health checks to verify that configuration reload both took effect and is a "good" configuration
- change-child-pid
  The configurator will monitor the set of child pids for the service's MAINPID for changes. If no changes occur (that is the service does not rotate its children) within ReloadTimeout then the configurator will enter OnPendingFailure. If the service has no child pids then the configurator will enter OnPendingFailure.
- unicorn-health-comparison
  The configurator will read health data from both active unicorn masters after BakeTime. If the new master is failing notably more requests than the previous master, the configurator will enter OnPendingFailure.

Communicating with systemd:
As Debian 11 still uses a pre-JS version of polkit we can't just grant the configurator limited permissions to manipulate systemd. Instead, we use a set of signal files monitored with systemd path units to trigger actions in systemd.
