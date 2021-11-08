# frozen_string_literal: true

require 'lifecycle/op_base'

require 'erb'

module Op
  class CompileTemplates < Lifecycle::OpBase
    reads :template_defs, :configuration_directory
    writes :compiled_templates

    def call
      self.compiled_templates = template_defs.each_with_object({}) do |(key, templ_def), hash|
        filename = File.join(configuration_directory, 'templates', templ_def.src)
        begin
          templ = ERB.new(File.read(filename))
          templ.filename = filename
          hash[key] = templ.def_class(Object, 'render(profiles)').new
        rescue SyntaxError, StandardError => e
          error filename, e
        end
      end
    end
  end
end
