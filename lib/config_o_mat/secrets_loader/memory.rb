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

require 'lifecycle_vm'

module ConfigOMat
  module SecretsLoader
    class Memory < LifecycleVM::Memory
      attr_reader :secretsmanager_client

      attr_accessor :secrets_cache, :secret_defs_to_load, :loaded_secrets, :loading_secret

      def initialize(
        secretsmanager_client: nil,
        secret_defs_to_load: [],
        secrets_cache: {},
        loading_secret: nil,
        logger: nil
      )
        @secretsmanager_client = secretsmanager_client
        @secret_defs_to_load = secret_defs_to_load
        @secrets_cache = secrets_cache
        @loading_secret = loading_secret
        @loaded_secrets = {}
        @logger = logger
      end

       def update_secret_defs_to_load(defs)
        @loaded_secrets = {}
        @secret_defs_to_load = defs
        self
      end
    end
  end
end
