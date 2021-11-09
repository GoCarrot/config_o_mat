# frozen_string_literal: true

require 'cond/services_to_reload'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Cond::ServicesToReload do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      services_to_reload: services_to_reload
    )
  end

  context 'with no services to reload' do
    let(:services_to_reload) { [] }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with services to reload' do
    let(:services_to_reload) { [:service0, :service1] }

    it 'is true' do
      expect(result).to be true
    end
  end
end
