# frozen_string_literal: true

require 'op/apply_all_profiles'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::ApplyAllProfiles do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      profiles_to_apply: profiles_to_apply,
      applied_profiles: applied_profiles
    )
  end

  let(:profiles_to_apply) do
    [
      LoadedProfile.new(:source0, '1', answer: 42),
      LoadedProfile.new(:source1, '3', answer: 181)
    ]
  end

  let(:applied_profiles) { {} }

  it 'applies all profiles to apply' do
    expect(state).to have_attributes(
      profiles_to_apply: [],
      applied_profiles: Hash[profiles_to_apply.map { |prof| [prof.name, prof] }]
    )
  end

  context 'with profiles already applied' do
    let(:applied_profiles) do
      {
        source1: LoadedProfile.new(:source1, '2', answer: 5),
        source2: LoadedProfile.new(:source2, '8', answer: 255)
      }
    end

    it 'applies all profiles to apply and keeps exisiting profiles' do
      expect(state).to have_attributes(
        profiles_to_apply: [],
        applied_profiles: {
          source0: profiles_to_apply[0],
          source1: profiles_to_apply[1],
          source2: applied_profiles[:source2]
        }
      )
    end
  end
end
