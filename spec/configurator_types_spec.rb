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

require 'configurator_types'

RSpec.shared_examples 'configuration type equality' do
  it 'is equal to another instance with the same settings' do
    expect(subject).to be == described_class.new(opts)
  end

  it 'is not equal to another instance with different settings' do
    expect(subject).not_to be == described_class.new(opts.merge(difference))
  end

  it 'is not equal to a different type' do
    expect(subject).not_to be == opts
  end
end

RSpec.describe Service do
  let(:opts) do
    {
      systemd_unit: systemd_unit, restart_mode: restart_mode, templates: templates
    }
  end

  let(:systemd_unit) { 'test0' }
  let(:restart_mode) { 'restart' }
  let(:templates) { ['templ0'] }

  let(:difference) { { systemd_unit: 'foo' } }

  subject { described_class.new(opts) }

  include_examples 'configuration type equality'

  context 'without any settings' do
    let(:systemd_unit) { nil }
    let(:restart_mode) { nil }
    let(:templates) { nil }

    it 'reports errors' do
      subject.validate
      expect(subject.errors).to match(
        templates: ['must be present', 'must be an array of strings'],
        systemd_unit: ['must be present'],
        restart_mode: ['must be one of [:restart, :flip_flop]']
      )
    end
  end
end

RSpec.describe Template do
  let(:opts) do
    {
      src: src, dst: dst
    }
  end

  let(:src) { 'foo.conf' }
  let(:dst) { 'foo.conf' }

  let(:difference) { { dst: 'bar.conf' } }

  subject { described_class.new(opts) }

  include_examples 'configuration type equality'

  context 'without any settings' do
    let(:src) { nil }
    let(:dst) { nil }

    it 'reports errors' do
      subject.validate
      expect(subject.errors).to match(
        src: ['must be present'],
        dst: ['must be present']
      )
    end
  end
end

RSpec.describe Profile do
  let(:opts) do
    {
      application: application, environment: environment, profile: profile
    }
  end

  let(:application) { 'test' }
  let(:environment) { 'test' }
  let(:profile) { 'test' }
  let(:difference) { { application: 'other' } }

  subject { described_class.new(opts) }

  include_examples 'configuration type equality'

  context 'without any settings' do
    let(:application) { nil }
    let(:environment) { nil }
    let(:profile) { nil }

    it 'reports errors' do
      subject.validate
      expect(subject.errors).to match(
        application: ['must be present'],
        environment: ['must be present'],
        profile: ['must be present']
      )
    end
  end
end
