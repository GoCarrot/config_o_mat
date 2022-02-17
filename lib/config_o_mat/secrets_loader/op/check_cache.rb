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

require 'lifecycle_vm/op_base'

module ConfigOMat
  module Op
    class CheckCache < LifecycleVM::OpBase
      reads :loading_secret, :secrets_cache, :loaded_secrets
      writes :loading_secret, :loaded_secrets

      def call
        # If we're referencing a secret by its version stage, never cache it, since these can be
        # updated out from under us.
        return unless loading_secret.version_stage.nil? || loading_secret.version_stage.empty?

        cached_secret = secrets_cache[loading_secret.secret_id]

        if cached_secret && cached_secret.version_id == loading_secret.version_id
          logger&.info(:cached_secret, name: loading_secret.name, version_id: loading_secret.version_id)
          loaded_secrets[loading_secret] = cached_secret
          self.loading_secret = nil
        elsif cached_secret
          logger&.info(
            :invalid_cached_secret,
            name: loading_secret.name,
            expected_version_id: loading_secret.version_id,
            cached_version_id: cached_secret.version_id
          )
        end
      end
    end
  end
end
