# frozen_string_literal: true

require 'op/notify_systemd_start'

RSpec.describe Op::NotifySystemdStart do
  def perform
    described_class.call(state)
  end

  before do
    @notifier = class_double('SdNotify').as_stubbed_const(transfer_nested_constants: true)
    allow(@notifier).to receive(:ready)
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new()
  end

  it 'notifies systemd that we are ready' do
    expect(@notifier).to have_received(:ready)
  end
end
