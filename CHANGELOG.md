## 0.5.7

BUG FIXES:

* Use `ENV.to_h` in initialization for Ruby 3+ compatibility

## 0.5.6

BUG FIXES:

* Only use dualstack endpoints for S3 client. AppConfig does not support IPv6, standard Secrets Manager endpoints already are dualstack.

## 0.5.5

ENHANCEMENTS:

* Use dualstack endpoints for AWS clients to support IPv6.

## 0.5.4

ENHACEMENTS:

* Update to ruby-dbus 0.19.0, from 0.16.0.

## 0.5.3

BUG FIXES:

* When restart_mode: none, output dropins to load credentials for services.

## 0.5.2

* Rerelease of 0.5.1 with merged PRs.

## 0.5.1

ENHANCEMENTS:

* Added restart_mode: none, to prevent service restarts on a configuration update.

## 0.5.0

NEW FEATURES:

* Profiles can now specify an s3_fallback key. If AWS AppConfig is unreachable, we will fall back to loading the specified S3 object from the top level configured fallback_s3_bucket and interpreting it as a response from AWS AppConfig. For best results enable versioning on the bucket. It is an error to specify an s3_fallback key if the configuration does not have a top level fallback_s3_bucket.
* AppConfig responses can request that the s3_fallback be used by setting a top level "aws:chaos_config" key to true. This allows for deployments which AppConfig deployments which can test the fallback mechanism. If a chaos config load fails, the source AppConfig profile will remain in use. Chaos config is ignored in error recovery scenarios.

BUG FIXES:

* config_o_mat-configurator/meta_configurator now correctly log the op that errored.

## 0.4.4

BUG FIXES:

* Fix MetaConfigurator with new GC parameters.

## 0.4.3

BUG FIXES:

* Fix MetaConfigurator with new GC parameters.

## 0.4.2

NEW FEATURES:

* gc_compact configuration variable. If set, will run `GC.compact` every given number of ticks (roughly seconds).
* gc_stat configuration variable. If set, will log `GC.stat` at the info level every given number of ticks (roughly seconds).

ENHANCEMENTS:

* Now remove ec2_metadata.iam key from Facter. This value updated every hour or so causing spurious template regeneration and did not contain actionable information.

## 0.4.1

ENHANCEMENTS:

* Omit empty lines in generated config when using <% %> ERB templates.

## 0.4.0

NEW FEATURES:

* Facter support. In your configomat config set a top level `facter` key to either truthy or a string. If truthy, facter data will be exposed in a profile named `facter` in all templates. If set to a string, facter data will be exposed in a profile with the given name in all templates.
* Attempting to access a configuration variable from a profile or secret that does not exist using `#[]` will now raise an exception indicating the key being incorrectly accessed. If you need to access optionally present configuration variables from profiles or secrets use `#fetch(key, nil)`.

## 0.3.0

NEW FEATURES:

* AWS Secrets Manager support, through an AWS AppConfig configuration. Values to pull from AWS Secrets Manager can be set using an "aws:secrets" key in any loaded AWS AppConfig JSON or YAML configuration. The value must be a dictionary. Keys in this dictionary will be exposed in the #secrets hash on the profile in templates. Values in this dictionary must be a dictionary containing at a minimum a `secret_id` key, which must be the id of an AWS Secrets Manager Secret. The dictionary may also contain a `version_id` or `version_stage` key to indicate which version of the secret to load, and a `content_type` key which may be one of `text/plan`, `application/json`, or `application/x-yaml` to indicate how the secret data should be parsed.

## 0.2.1

BUG FIXES:

* restart_all actually works.

## 0.2.0

NEW FEATURES:

* restart_all restart_mode for services to restart all running instances of an instantiated service.

## 0.1.0

Initial release
