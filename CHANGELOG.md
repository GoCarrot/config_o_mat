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
