# frozen_string_literal: true

require 'cond/first_run'

require 'configurator_memory'

RSpec.describe Cond::FirstRun do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      run_count: run_count
    )
  end

  context 'when run_count is 0' do
    let(:run_count) { 0 }

    it 'returns true' do
      expect(result).to be true
    end
  end

  context 'when early_exit is greater than 0' do
    let(:run_count) { rand(1_000_000) + 1 }

    it 'returns false' do
      expect(result).to be false
    end
  end
end
