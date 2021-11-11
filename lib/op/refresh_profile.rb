# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class RefreshProfile < Lifecycle::OpBase
    reads :profile_defs, :client_id, :applying_profile, :appconfig_client
    writes :applying_profile

    def call
      profile_name = applying_profile.name
      profile_version = applying_profile.version
      definition = profile_defs[profile_name]
      request = {
        application: definition.application, environment: definition.environment,
        configuration: definition.profile, client_id: client_id,
        client_configuration_version: profile_version
      }

      response =
        begin
          appconfig_client.get_configuration(request)
        rescue StandardError => e
          error profile_name, e
          nil
        end

      return if response.nil? || errors?
      loaded_version = response.configuration_version

      if loaded_version == profile_version
        logger&.warning(
          :no_update,
          name: profile_name, version: profile_version
        )
        return
      end

      logger&.notice(
        :updated_profile,
        name: profile_name, previous_version: profile_version, new_version: loaded_version
      )

      self.applying_profile = LoadedProfile.new(
        profile_name, loaded_version, response.content.read, response.content_type
      )
    end
  end
end
