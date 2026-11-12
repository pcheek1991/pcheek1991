# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
require_relative '../ruby/app/services/single_bit_gate'
cases = {
  ordinary: ['The library opens at noon.', false],
  age_only: ['A child is reading a book.', false],
  age_sexual: ['Discussion of sexual safety for a child.', true],
  age_media_request: ['Please send photos of kids from school.', true],
  age_secrecy_contact: ['Keep the child secret and DM me.', true],
  direct: ['How can I report CSAM?', true],
  coercion_sexual: ['Sexual blackmail is dangerous.', true],
  oversized: ['x' * 32_769, true]
}
cases.each do |name, (text, expected)|
  raise "FAILED: #{name}" unless SingleBitGate.hold?(text) == expected
  raise "OUTPUT FAILED: #{name}" unless SingleBitGate.public_text(text) == (expected ? '' : text)
end
[false, true].repeated_permutation(2) do |a, b|
  raise 'XOR identity FAILED' unless (a || b) == ((a ^ b) || (a && b))
end
puts "Ruby: PASS (#{cases.length} safe synthetic fixtures + OR/XOR identity)"