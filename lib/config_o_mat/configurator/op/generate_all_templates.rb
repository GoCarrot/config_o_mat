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
    class GenerateAllTemplates < LifecycleVM::OpBase
      reads :template_defs, :dependencies, :applied_profiles, :applying_profile, :generated_templates,
            :compiled_templates, :runtime_directory, :rejected_profiles

      writes :generated_templates, :services_to_reload, :applying_profile, :rejected_profiles

      def call
        self.services_to_reload = []

        failures = {}
        # Checked here rather than in StageOneProfile so a profile that failed to parse is still the
        # applying_profile, and can be rejected below like one that fails to render.
        failures[applying_profile.name] = applying_profile.errors if applying_profile&.errors?

        rendered = failures.empty? ? render_all(failures) : {}

        return reject_applying_profile(failures) if !failures.empty? && applying_profile
        return failures.each { |(key, err)| error key, err } unless failures.empty?

        # Only write once every template has rendered, so a failure leaves all output as it was.
        rendered.each do |(key, contents)|
          generated = GeneratedTemplate.new(contents)
          next if generated_templates[key] == generated

          destination_file = File.join(runtime_directory, template_defs[key].dst)
          logger&.notice(:template_update, template: key, file: destination_file, digest: generated.digest)

          generated_templates[key] = generated
          File.open(destination_file, 'w') { |f| f.write(contents) }
          dependencies[key]&.each { |service| services_to_reload << service }
        end

        services_to_reload.uniq!

        logger&.notice(:scheduled_restarts, services: services_to_reload)
      end

    private

      def render_all(failures)
        profiles = applied_profiles
        profiles[applying_profile.name] = applying_profile if applying_profile

        template_defs.each_key.with_object({}) do |key, rendered|
          rendered[key] = compiled_templates[key].render(profiles)
        rescue StandardError => e
          failures[key] = e
        end
      end

      # Keep the last good output; exiting makes systemd restart us, and every restart receives every profile again.
      def reject_applying_profile(failures)
        logger&.error(
          :profile_rejected,
          name: applying_profile.name, profile_version: applying_profile.version, errors: failures
        )

        rejected_profiles[applying_profile.name] = applying_profile
        self.applying_profile = nil
      end
    end
  end
end
