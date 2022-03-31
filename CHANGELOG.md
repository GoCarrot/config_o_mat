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
