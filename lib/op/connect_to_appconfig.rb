# frozen_string_literal: true

require 'lifecycle/op_base'

require 'aws-sdk-appconfig'

module Op
  class ConnectToAppconfig < Lifecycle::OpBase
    reads :region
    writes :appconfig_client

    def call
      client_opts = { logger: logger }
      client_opts[:region] = region if region

      self.appconfig_client = Aws::AppConfig::Client.new(client_opts)
    end
  end
end
