# frozen_string_literal: true

require 'lifecycle/op_base'

require 'aws-sdk-appconfig'

module Op
  class RefreshAllProfiles < Lifecycle::OpBase
    reads :profile_defs, :applied_profiles, :client_id
    writes :profiles_to_apply

    def call
      client = Aws::AppConfig::Client.new
      self.profiles_to_apply = []

      profile_defs.each do |(profile_name, definition)|
        request = {
          application: definition.application, environment: definition.environment,
          configuration: definition.profile, client_id: client_id
        }

        current_version = applied_profiles&.fetch(profile_name, nil)&.version
        request[:client_configuration_version] = current_version if current_version

        response =
          begin
            client.get_configuration(request)
          rescue StandardError => e
            error profile_name, e
            nil
          end

        next if response.nil?

        loaded_version = response.configuration_version
        next if current_version && loaded_version == current_version

        profiles_to_apply << LoadedProfile.new(
          profile_name, loaded_version, response.content.read, response.content_type
        )
      end
    end
  end
end
