# frozen_string_literal: true

# Copyright 2021 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'config_o_mat/configurator/op/notify_systemd_start'

RSpec.describe ConfigOMat::Op::NotifySystemdStart do
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
    ConfigOMat::Configurator::Memory.new()
  end

  it 'notifies systemd that we are ready' do
    expect(@notifier).to have_received(:ready)
  end
end
