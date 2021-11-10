# frozen_string_literal: true

require 'op/next_tick'

require 'configurator_memory'

RSpec.describe Op::NextTick do
  def perform
    described_class.call(state)
  end

  before do
    allow(Kernel).to receive(:sleep) { |time| time.to_i }
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      last_refresh_time: last_refresh_time,
      refresh_interval: refresh_interval,
      run_count: run_count
    )
  end

  let(:last_refresh_time) { Time.now.to_i }
  let(:refresh_interval) { 5 }
  let(:run_count) { rand(1_000_000) }

  context "when we aren't due to refresh profiles" do
    it 'sleeps' do
      expect(Kernel).to have_received(:sleep).with(be > 0)
    end

    it 'updates state and proceeds to running' do
      expect(state).to have_attributes(
        next_state: :running,
        run_count: run_count + 1
      )
    end
  end

  context "when we are due to refresh profiles" do
    let(:last_refresh_time) { Time.now.to_i - (refresh_interval + 1) }

    it 'sleeps' do
      expect(Kernel).to have_received(:sleep).with(be > 0)
    end

    it 'updates state and proceeds to refreshing_profiles' do
      expect(state).to have_attributes(
        next_state: :refreshing_profiles,
        run_count: run_count + 1
      )
    end
  end
end
