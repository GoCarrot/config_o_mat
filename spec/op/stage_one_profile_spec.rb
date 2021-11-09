# frozen_string_literal: true

require 'op/stage_one_profile'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::StageOneProfile do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      profiles_to_apply: profiles_to_apply,
    )
  end

  let(:profiles_to_apply) do
    [
      LoadedProfile.new(:source0, '1', answer: 42),
      LoadedProfile.new(:source1, '3', answer: 181)
    ]
  end

  it 'sets a profile from profiles to apply as the profile being applied' do
    expect(state).to have_attributes(
      profiles_to_apply: eq(profiles_to_apply).and(include(state.applying_profile)),
      applying_profile: an_instance_of(LoadedProfile)
    )
  end
end
