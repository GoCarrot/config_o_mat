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

require 'config_o_mat/secrets_loader/op'
require 'config_o_mat/secrets_loader/cond'
require 'config_o_mat/secrets_loader/memory'

module ConfigOMat
  module SecretsLoader
    class VM < LifecycleVM::VM
      memory_class ConfigOMat::SecretsLoader::Memory

      on :start, then: {
        case: Cond::SecretsToLoad,
        when: {
          true => {
            do: Op::StageOneSecret,
            then: :check_cache
          },
          false => {
            then: :exit
          }
        }
      }

      on :check_cache, do: Op::CheckCache, then: {
        case: Cond::RequiresLoad,
        when: {
          true => :load_secret,
          false => :start
        }
      }

      on :load_secret, do: Op::LoadSecret, then: :start
    end
  end
end
