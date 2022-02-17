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

require 'config_o_mat/flip_flopper/op/stop_activating_instance'

require 'config_o_mat/flip_flopper/memory'

require 'tmpdir'

RSpec.describe ConfigOMat::Op::StopActivatingInstance do
  def perform
    described_class.call(state)
  end

  before do
    @runtime_directory = Dir.mktmpdir
    touch_files.each do |file|
      path = File.join(runtime_directory, file)
      FileUtils.touch(path)
      @stat ||= {}
      @stat[file] = File.stat(path)
    end
    @result = perform
  end

  after do
    FileUtils.remove_entry @runtime_directory
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::FlipFlopper::Memory.new(
      runtime_directory: runtime_directory,
      service: 'test@',
      activating_instance: [1, 2].sample,
      logger: logger
    )
  end

  let(:runtime_directory) { @runtime_directory }
  let(:touch_files) { [] }
  let(:logger) { nil }

  context 'without a stop file present' do
    it 'touches the stop file' do
      expect { File.stat(File.join(runtime_directory, "#{state.service}#{state.activating_instance}.stop")) }.not_to raise_error
    end
  end

  context 'with a stop file present' do
    let(:touch_files) { ["#{state.service}#{state.activating_instance}.stop"] }

    it 'touches the stop file' do
      expect(File.stat(File.join(runtime_directory, touch_files[0]))).to be > @stat[touch_files[0]]
    end
  end

  context 'with a logger' do
    let(:logger) do
      @messages = []
      l = LogsForMyFamily::Logger.new
      l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
      l
    end

    it 'logs service start' do
      expect(@messages).to include(
        contain_exactly(:notice, :service_stop, a_hash_including(name: "#{state.service}#{state.activating_instance}"))
      )
    end
  end
end
