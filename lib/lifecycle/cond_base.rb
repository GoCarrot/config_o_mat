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

module Lifecycle
  class CondBase
    class InvalidAttr < RuntimeError
      attr_reader :cond_class, :attribute

      def initialize(cond_class, attribute)
        @cond_class = cond_class
        @attribute = attribute
        super("Invalid attribute #{attribute} access by #{cond_class.name}")
      end
    end

    def self.reads(*attrs)
      @reads ||= {}
      @reads.merge!(Hash[attrs.map { |attribute| [attribute, :"@#{attribute}"] }])
      attr_reader(*attrs)
    end

    def self.call(state)
      obj = allocate

      @reads&.each do |(attribute, ivar)|
        raise InvalidAttr.new(self, attribute) unless state.respond_to?(attribute)

        obj.instance_variable_set(ivar, state.send(attribute).clone)
      end

      obj.send(:initialize, state.logger)
      obj.send(:call)
    end

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def call; end
  end
end
