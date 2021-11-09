# frozen_string_literal: true

require 'cond/profiles_to_apply'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Cond::ProfilesToApply do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      profiles_to_apply: profiles_to_apply
    )
  end

  context 'with no profiles to apply' do
    let(:profiles_to_apply) { [] }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with profiles to apply' do
    let(:profiles_to_apply) { [LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json')] }

    it 'is true' do
      expect(result).to be true
    end
  end
end
