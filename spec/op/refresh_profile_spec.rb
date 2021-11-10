# frozen_string_literal: true

require 'op/refresh_profile'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::RefreshProfile do
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
      client_id: client_id,
      applying_profile: applying_profile
    )
  end

  let(:profile_defs) do
    {
      source0: Profile.new(application: 'test', environment: 'test', profile: 'test')
    }
  end

  let(:applying_profile) do
    LoadedProfile.new(:source0, '1', '{"answer": 42', 'application/json')
  end

  let(:client_id) { SecureRandom.uuid }

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '2', content_type: 'application/json' },
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


  context 'when the profile is updated' do
    it 'updates applying_profile' do
      expect(state.applying_profile).to eq(
        LoadedProfile.new(:source0, '2', { answer: 42 }.to_json, 'application/json')
      )
    end
  end

  context 'when the profile is not updated' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
      }
    end

    it 'does not update applying_profile' do
      expect(state.applying_profile).to eq applying_profile
    end

    it 'does not error' do
      expect(result.errors?).to be false
    end
  end

  context 'when the update fails' do
    let(:stub_responses) do
      {
        'test' => 'BadRequestException',
      }
    end

    it 'errors' do
      expect(result.errors).to  match(
        source0: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end
end