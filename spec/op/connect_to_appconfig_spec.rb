# frozen_string_literal: true

require 'op/connect_to_appconfig'

require 'configurator_memory'

RSpec.describe Op::ConnectToAppconfig do
  def perform
    described_class.call(state)
  end

  before do
    allow(Aws::AppConfig::Client).to receive(:new).and_return(client_stub)
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      region: region,
      logger: logger
    )
  end

  let(:client_stub) do
    Aws::AppConfig::Client.new(stub_responses: true)
  end

  let(:region) { nil }
  let(:logger) { nil }

  it 'uses the default region' do
    expect(Aws::AppConfig::Client).to have_received(:new).with(hash_excluding(:region))
  end

  context 'with a region' do
    let(:region) { 'us-west-2' }

    it 'uses the configured region' do
      expect(Aws::AppConfig::Client).to have_received(:new).with(a_hash_including(region: region))
    end
  end

  context 'with a logger' do
    let(:logger) { LogsForMyFamily::Logger.new }

    it 'passes the logger to the client' do
      expect(Aws::AppConfig::Client).to have_received(:new).with(a_hash_including(logger: logger))
    end
  end
end
