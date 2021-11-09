# frozen_string_literal: true

require 'cond/early_exit'

require 'configurator_memory'

RSpec.describe Cond::EarlyExit do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      early_exit: early_exit
    )
  end

  context 'when early_exit is true' do
    let(:early_exit) { true }

    it 'returns true' do
      expect(result).to be true
    end
  end

  context 'when early_exit is false' do
    let(:early_exit) { false }

    it 'returns false' do
      expect(result).to be false
    end
  end
end
