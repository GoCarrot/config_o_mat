# frozen_string_literal: true

require 'cond/next_state'

require 'configurator_memory'

RSpec.describe Cond::NextState do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      next_state: next_state
    )
  end

  let(:next_state) { %i[running refreshing_profiles].sample }

  it 'returns the next state' do
    expect(result).to eq next_state
  end
end
