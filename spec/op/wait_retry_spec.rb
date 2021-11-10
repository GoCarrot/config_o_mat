# frozen_string_literal: true

require 'op/wait_retry'

require 'configurator_memory'

RSpec.describe Op::WaitRetry do
  def perform
    described_class.call(state)
  end

  before do
    @sleep_time = nil
    allow(Kernel).to receive(:sleep) { |arg| @sleep_time = arg.to_i }
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      retry_wait: retry_wait,
      retry_count: retry_count,
      retries_left: retries_left,
      logger: logger
    )
  end

  let(:retry_wait) { 10 }
  let(:retry_count) { 3 }
  let(:retries_left) { 3 }
  let(:logger) { nil }

  it 'decrements retries_left' do
    expect(state.retries_left).to eq retries_left - 1
  end

  it 'sleeps' do
    expect(Kernel).to have_received(:sleep).with(be_within(retry_wait / 2).of(retry_wait))
  end

  context 'when we have already retried' do
    let(:retries_left) { 1 }

    it 'decrements retries_left' do
      expect(state.retries_left).to eq 0
    end

    it 'sleeps longer' do
      expect(Kernel).to have_received(:sleep).with(be_within(retry_wait / 2).of(retry_wait * 4))
    end
  end

  context 'with a logger' do
    let(:logger) do
      @messages = []
      l = LogsForMyFamily::Logger.new
      l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
      l
    end

    it 'logs the retry' do
      expect(@messages).to include(
        contain_exactly(:notice, :retry_wait, a_hash_including(wait: @sleep_time))
      )
    end
  end
end
