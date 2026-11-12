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
  oversized: ['x' * 32_769, true],
  simultaneous_signals: ['A child in a sexual blackmail story.', true]
}
cases.each do |name, (text, expected)|
  raise "FAILED: #{name}" unless SingleBitGate.hold?(text) == expected
  raise "OUTPUT FAILED: #{name}" unless SingleBitGate.public_text(text) == (expected ? '' : text)
end
# All 32 five-input combinations: OR = XOR parity OR two-or-more overlap.
32.times do |mask|
  bits = (0..4).map { |i| (mask & (1 << i)) != 0 }
  parity = bits.reduce(false) { |v, bit| v ^ bit }
  overlap = bits.count(true) >= 2
  raise "PENTAGON XOR identity FAILED: #{mask}" unless bits.any? == (parity || overlap)
end
puts "Ruby: PASS (#{cases.length} synthetic fixtures + 32 pentagon states)"