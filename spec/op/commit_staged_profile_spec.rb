# frozen_string_literal: true

require 'op/commit_staged_profile'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::CommitStagedProfile do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      applied_profiles: applied_profiles,
      applying_profile: applying_profile
    )
  end

  let(:source0) { LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json') }
  let(:source1) { LoadedProfile.new(:source1, '2', { answer: 5 }.to_json, 'application/json') }
  let(:n_source1) { LoadedProfile.new(:source1, '3', { answer: 181 }.to_json, 'application/json') }
  let(:applying_profile) { n_source1 }
  let(:applied_profiles) do
    {
      source0: source0,
      source1: source1
    }
  end

  it 'applies the current applying profile' do
    expect(state).to have_attributes(
      applied_profiles: applied_profiles.yield_self { |ap| ap.dup.merge(applying_profile.name => applying_profile) },
      applying_profile: nil,
    )
  end
end
