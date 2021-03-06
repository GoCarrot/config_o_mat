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

require 'erb'

module ConfigOMat
  module Op
    class CompileTemplates < LifecycleVM::OpBase
      reads :template_defs, :configuration_directory
      writes :compiled_templates

      def call
        self.compiled_templates = template_defs.each_with_object({}) do |(key, templ_def), hash|
          filename = File.join(configuration_directory, 'templates', templ_def.src)
          begin
            templ = ERB.new(File.read(filename), trim_mode: '<>')
            templ.filename = filename
            hash[key] = templ.def_class(Object, 'render(profiles)').new
          rescue SyntaxError, StandardError => e
            error filename, e
          end
        end
      end
    end
  end
end
