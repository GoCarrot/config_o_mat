# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class GenerateAllTemplates < Lifecycle::OpBase
    reads :template_defs, :dependencies, :applied_profiles, :applying_profile, :generated_templates,
          :compiled_templates, :runtime_directory

    writes :generated_templates, :services_to_reload

    def call
      # By doing the error check here instead of in StageOneProfile we ensure that the applying_profile
      # gets set in memory, even if errored, which simplifies the retry logic.
      error applying_profile.name, applying_profile.errors if applying_profile&.errors?

      return if errors?

      profiles = applied_profiles
      profiles[applying_profile.name] = applying_profile if applying_profile
      self.services_to_reload = []

      template_defs.each do |(key, templ_def)|
        compiled_template = compiled_templates[key]

        begin
          rendered = compiled_template.render(profiles)
        rescue StandardError => e
          error key, e
          next
        end

        generated = GeneratedTemplate.new(rendered)

        if generated_templates[key] != generated
          destination_file = File.join(runtime_directory, templ_def.dst)
          logger&.notice(:template_update, template: key, file: destination_file, digest: generated.digest)

          generated_templates[key] = generated
          File.open(destination_file, 'w') { |f| f.write(rendered) }
          dependencies[key].each { |service| services_to_reload << service }
        end

        services_to_reload.uniq!
      end
    end
  end
end
