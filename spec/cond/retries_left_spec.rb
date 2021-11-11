# frozen_string_literal: true

require 'cond/retries_left'

require 'configurator_memory'
require 'configurator_types'

require 'logsformyfamily'

RSpec.describe Cond::RetriesLeft do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      retries_left: retries_left,
      applying_profile: applying_profile,
      logger: logger
    ).tap do |mem|
      mem.error_op = error_op
    end
  end

  let(:logger) { nil }
  let(:retries_left) { 3 }
  let(:applying_profile) { LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json') }
  let(:errors) { { source0: ['syntax error'] } }
  let(:error_op) do
    instance_double("Op::StageOneProfile").tap do |dbl|
      allow(dbl).to receive(:errors?).and_return(true)
      allow(dbl).to receive(:errors).and_return(errors)
    end
  end

  context 'when it can retry' do
    it 'proceeds with the retry' do
      expect(result).to be true
    end
  end

  context 'when retries_left is 0' do
    let(:retries_left) { 0 }

    it 'cannot retry' do
      expect(result).to be false
    end
  end

  context 'when no profile is being applied' do
    let(:applying_profile) { nil }

    it 'cannot retry' do
      expect(result).to be false
    end
  end

  context 'with a logger' do
    let(:logger) do
      @messages = []
      l = LogsForMyFamily::Logger.new
      l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
      l
    end

    it 'logs an error' do
      expect(@messages).to include(
        contain_exactly(
          :error, :op_failure, a_hash_including(errors: errors)
        )
      )
    end
  end
end
