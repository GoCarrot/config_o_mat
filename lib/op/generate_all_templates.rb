# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class GenerateAllTemplates < Lifecycle::OpBase
    reads :template_defs, :dependencies, :applied_profiles, :applying_profile, :generated_templates,
          :compiled_templates, :runtime_directory

    writes :generated_templates, :services_to_reload

    def call
      profiles = applied_profiles.merge(applying_profile || {})
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
          self.services_to_reload ||= Set.new
          dependencies[key].each { |service| services_to_reload << service }
        end
      end
    end
  end
end
