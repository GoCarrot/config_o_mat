# frozen_string_literal: true

# Copyright 2026 Teak.io, Inc.
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

require 'config_o_mat/configurator'
require 'config_o_mat/shared/types'

require 'aws-sdk-appconfig'
require 'erb'
require 'tmpdir'

# Steady-state behaviour: a running configurator receives a profile version its templates can't render.
RSpec.describe ConfigOMat::Configurator::VM do
  # Starts at :refreshing_profiles with a profile already applied, as a host that has been up a while.
  let(:steady_vm_class) do
    parent = described_class
    Class.new(parent) do
      @config = parent.config.dup
      @config.initial_state = :refreshing_profiles
    end
  end

  let(:log) { [] }
  let(:logger) do
    entries = log
    Object.new.tap do |l|
      l.define_singleton_method(:method_missing) { |level, event = nil, **data| entries << [level, event, data] }
      l.define_singleton_method(:respond_to_missing?) { |*| true }
    end
  end

  let(:template) { 'answer=<%= profiles[:app].to_h[:answer] %>' }
  let(:compiled) do
    ERB.new(template, trim_mode: '<>').def_class(Object, 'render(profiles)').new
  end

  # Versions AppConfig serves, one per request; the last one repeats.
  let(:served) { [] }
  let(:requests) { [] }
  let(:appconfig) do
    reqs = requests
    versions = served
    Aws::AppConfig::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_configuration, proc do |request|
        reqs << request.params
        version, body = versions.length > 1 ? versions.shift : versions.first
        if request.params[:client_configuration_version] == version
          { content: StringIO.new(''), configuration_version: version, content_type: 'application/json' }
        else
          { content: StringIO.new(body.to_json), configuration_version: version, content_type: 'application/json' }
        end
      end)
    end
  end

  def loaded(version, body)
    ConfigOMat::LoadedProfile.new(
      ConfigOMat::LoadedAppconfigProfile.new(:app, version, body.to_json, 'application/json'), nil
    )
  end

  let(:runtime_directory) { Dir.mktmpdir }
  after { FileUtils.remove_entry runtime_directory }

  let(:rendered_path) { File.join(runtime_directory, 'app.conf') }

  let(:memory) do
    ConfigOMat::Configurator::Memory.new(
      run_count: 1,
      refresh_interval: -1,
      profile_defs: { app: ConfigOMat::Profile.new(application: 'app', environment: 'test', profile: 'app') },
      template_defs: { app: ConfigOMat::Template.new(src: 'app.conf', dst: 'app.conf') },
      compiled_templates: { app: compiled },
      dependencies: {},
      applied_profiles: { app: loaded('1', { answer: 42 }) },
      generated_templates: { app: ConfigOMat::GeneratedTemplate.new('answer=42') },
      runtime_directory: runtime_directory,
      appconfig_client: appconfig,
      client_id: 'test',
      logger: logger
    )
  end

  # Runs the VM until it has slept `ticks` times, or until it terminates on its own.
  def run(ticks)
    sleeps = 0
    allow(Kernel).to receive(:sleep) do
      sleeps += 1
      throw :stop if sleeps >= ticks
    end
    allow(SdNotify).to receive(:watchdog)
    vm = steady_vm_class.new(memory)
    still_running = true
    catch(:stop) do
      vm.call
      still_running = false
    end
    [vm, still_running]
  end

  before { File.write(rendered_path, 'answer=42') }

  context 'when a new version drops a key the template reads' do
    before { served.push(['2', { other: 1 }], ['2', { other: 1 }]) }

    it 'stays up, keeps the old output, logs an error, and stops re-receiving the version' do
      vm, still_running = run(10)

      expect(vm.errors?).to be false
      expect(still_running).to be true
      expect(File.read(rendered_path)).to eq 'answer=42'
      expect(memory.applied_profiles[:app].version).to eq '1'
      expect(log).to include(
        [:error, :profile_rejected, hash_including(name: :app, profile_version: '2', errors: { app: an_instance_of(KeyError) })]
      )
      expect(requests.drop(1).map { |r| r[:client_configuration_version] }).to all(eq '2')
    end
  end

  context 'when a later version fixes the key' do
    before { served.push(['2', { other: 1 }], ['2', { other: 1 }], ['3', { answer: 7 }]) }

    it 'applies the fixed version' do
      vm, = run(10)

      expect(vm.errors?).to be false
      expect(File.read(rendered_path)).to eq 'answer=7'
      expect(memory.applied_profiles[:app].version).to eq '3'
      expect(memory.rejected_profiles).to be_empty
    end
  end

  # IMDS dropping out on a host loses EC2 facts, e.g. "No key :tags in profile facter".
  context 'when facts lose a key a template reads' do
    def facts(tags)
      Marshal.load(Marshal.dump(Fixtures::Facter::DEFAULT)).tap do |f|
        f['ec2_tags'] = { 'Name' => 'web' } if tags
      end
    end

    let(:template) { 'name=<%= profiles[:facter].to_h[:ec2_tags][:Name] %>' }

    let(:memory) do
      ConfigOMat::Configurator::Memory.new(
        run_count: 1,
        refresh_interval: -1,
        profile_defs: { facter: ConfigOMat::FacterProfile.new },
        template_defs: { app: ConfigOMat::Template.new(src: 'app.conf', dst: 'app.conf') },
        compiled_templates: { app: compiled },
        dependencies: {},
        applied_profiles: { facter: @good_facts },
        generated_templates: { app: ConfigOMat::GeneratedTemplate.new('name=web') },
        runtime_directory: runtime_directory,
        logger: logger
      )
    end

    before do
      allow(Facter).to receive(:to_hash).and_return(facts(true))
      @good_facts = ConfigOMat::LoadedProfile.new(ConfigOMat::LoadedFacterProfile.new(:facter), nil)
      allow(Facter).to receive(:to_hash).and_return(*[facts(false)] * 5, facts(true))
      File.write(rendered_path, 'name=web')
    end

    it 'keeps the old output, stages the bad facts once, and recovers when they come back' do
      vm, still_running = run(10)

      expect(vm.errors?).to be false
      expect(still_running).to be true
      expect(File.read(rendered_path)).to eq 'name=web'
      expect(log).to include([:error, :profile_rejected, hash_including(name: :facter, errors: { app: an_instance_of(KeyError) })])
      expect(log.count { |l| l[1] == :updated_profile }).to eq 2
      expect(memory.rejected_profiles).to be_empty
    end
  end
end
