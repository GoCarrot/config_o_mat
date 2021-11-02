# frozen_string_literal: true

Dir[File.join(__dir__, 'op', '*')].sort.each { |file| require file }
