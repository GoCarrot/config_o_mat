# frozen_string_literal: true

require 'op/refresh_all_profiles'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::RefreshAllProfiles do
  def perform
    described_class.call(state)
  end

  before do
    allow(Aws::AppConfig::Client).to receive(:new).and_return(client_stub)
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      profile_defs: profile_defs,
      applied_profiles: applied_profiles,
      client_id: client_id
    )
  end

  let(:profile_defs) do
    {
      source0: Profile.new(application: 'test', environment: 'test', profile: 'test'),
      source1: Profile.new(application: 'foo', environment: 'bar', profile: 'boo'),
      source2: Profile.new(application: 'other', environment: 'test', profile: 'test')
    }
  end

  let(:applied_profiles) do
    {
      source0: LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
      source1: LoadedProfile.new(:source1, '1', { answer: 255 }.to_json, 'application/json')
    }
  end

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '1', content_type: 'application/json' },
      'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
      'other' => { content: StringIO.new({ answer: 255 }.to_json), configuration_version: '1', content_type: 'application/json' }
    }
  end

  let(:client_stub) do
    Aws::AppConfig::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_configuration, proc do |request|
        stub_responses[request.params[:application]]
      end
      )
    end
  end

  let(:client_id) { SecureRandom.uuid }

  context 'when all profiles refresh' do
    it 'includes versions for applied profiles' do
      expect(client_stub.api_requests).to contain_exactly(
        a_hash_including(
          params: { application: 'test', environment: 'test', configuration: 'test', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'foo', environment: 'bar', configuration: 'boo', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'other', environment: 'test', configuration: 'test', client_id: client_id }
        )
      )
    end

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        LoadedProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
        LoadedProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json')
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end
  end

  context 'with no applied profiles' do
    let(:applied_profiles) { nil }

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        LoadedProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
        LoadedProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json')
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end
  end

  context 'when a profile update errors' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
        'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
        'other' => 'BadRequestException'
      }
    end

    it 'errors' do
      expect(result.errors).to match(
        source2: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end
end
