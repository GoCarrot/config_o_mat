# frozen_string_literal: true

# Copyright 2021 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'lib/config_o_mat/version'

Gem::Specification.new do |spec|
  spec.name          = "config_o_mat"
  spec.version       = ConfigOMat::VERSION
  spec.authors       = ["Alex Scarborough"]
  spec.email         = ["alex@teak.io"]

  spec.summary       = "ConfigOMat applies AWS AppConfig to Systemd services."
  spec.homepage      = "https://github.com/GoCarrot/configurator"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/GoCarrot/configurator"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features|script)/}) }
  end

  spec.require_paths = ["lib"]
  spec.executables   = ["config_o_mat-configurator", "config_o_mat-meta_configurator"]

  spec.add_dependency('aws-sdk-appconfig', '~> 1.18')
  spec.add_dependency('aws-sdk-s3', '~> 1.114')
  spec.add_dependency('aws-sdk-secretsmanager', '~> 1.57')
  spec.add_dependency('logsformyfamily', '~> 0.2')
  spec.add_dependency('lifecycle_vm', '~> 0.1.1')
  spec.add_dependency('ruby-dbus', '~> 0.19.0')
  spec.add_dependency('sd_notify', '~> 0.1.1')
  spec.add_dependency('facter', ['~> 4.2', '>= 4.2.8'])

  spec.add_development_dependency('simplecov', '~> 0.22.0')
  spec.add_development_dependency('rspec', '~> 3.10')
end
