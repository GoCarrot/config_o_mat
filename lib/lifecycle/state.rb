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

require 'lifecycle/then'

module Lifecycle
  # Represents a state in the lifecycle.
  # A state may optionally define a single operation to perform, and then must
  # define which state to transition to next.
  # Transitions may be conditional, controlled by a subclass of Lifecycle::CondBase
  # @see Lifecycle::VM
  # @see Lifecycle::OpBase
  # @see Lifecycle::CondBase
  class State
    attr_reader :name, :op, :then

    def initialize(name, options)
      @name = name
      @op = options[:do]
      @then = Then.new(options[:then]) if options.key?(:then)
    end
  end
end
