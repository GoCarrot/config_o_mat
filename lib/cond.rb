# frozen_string_literal: true

Dir[File.join(__dir__, 'cond', '*')].sort.each { |file| require file }
