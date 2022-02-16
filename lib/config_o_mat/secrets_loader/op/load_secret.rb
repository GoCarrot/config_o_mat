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

require 'config_o_mat/shared/types'

module ConfigOMat
  module Op
    class LoadSecret < LifecycleVM::OpBase
      reads :loading_secret, :secrets_cache, :loaded_secrets, :secretsmanager_client
      writes :loading_secret, :loaded_secrets, :secrets_cache

      def call
        opts = {
          secret_id: loading_secret.secret_id
        }

        if loading_secret.version_id
          opts[:version_id] = loading_secret.version_id
        else
          opts[:version_stage] = loading_secret.version_stage
        end

        response =
          begin
            secretsmanager_client.get_secret_value(opts)
          rescue StandardError => e
            error loading_secret.name, e
            nil
          end

        return if response.nil? || errors?

        loaded_secret = LoadedSecret.new(
          loading_secret.name, loading_secret.secret_id, response.version_id,
          response.secret_string, loading_secret.content_type
        )

        logger&.info(
          :loaded_secret, name: loading_secret.name, arn: response.arn,
          version_id: response.version_id
        )

        begin
          loaded_secret.validate!
        rescue StandardError => e
          logger&.error(
            :invalid_secret, name: loading_secret.name, arn: response.arn,
            version_id: response.version_id, errors: e
          )
          error loaded_secret.name, e
        end

        return if errors?

        secrets_cache[loading_secret.secret_id] = loaded_secret
        loaded_secrets[loading_secret] = loaded_secret
        self.loading_secret = nil
      end
    end
  end
end
