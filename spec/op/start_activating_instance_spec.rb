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

require 'op/start_activating_instance'

require 'flip_flop_memory'

require 'tmpdir'

RSpec.describe Op::StartActivatingInstance do
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
    FlipFlopMemory.new(
      runtime_directory: runtime_directory,
      service: 'test@',
      activating_instance: [1, 2].sample,
    )
  end

  let(:runtime_directory) { @runtime_directory }
  let(:touch_files) { [] }

  context 'without a start file present' do
    it 'touches the start file' do
      expect { File.stat(File.join(runtime_directory, "#{state.service}#{state.activating_instance}.start")) }.not_to raise_error
    end
  end

  context 'with a start file present' do
    let(:touch_files) { ["#{state.service}#{state.activating_instance}.start"] }

    it 'touches the start file' do
      expect(File.stat(File.join(runtime_directory, touch_files[0]))).to be > @stat[touch_files[0]]
    end
  end
end
