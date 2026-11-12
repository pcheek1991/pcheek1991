# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
# FOR EVALUATION PURPOSES / NO WARRANTY / NO COPYRIGHT CLAIM / NO TRADEMARK
# CLAIM / NO INSURANCE / ONLY BEST EFFORT SELF DIRECTED AGENCY LOGIC.

# Drop-in Ruby 3+ / Rails service. Only final decision is a single Boolean.
class SingleBitGate
  MAX_BYTES = 32_768
  PATTERNS = {
    age: /\b(?:child|children|kids?|minors?|underage|preteen|teens?|teenagers?|(?:[1-9]|1[0-7])\s*(?:years?\s*old|yo))\b/i,
    sexual: /\b(?:sex|sexual|sexually|sexting|sexts?|nudes?|naked|porn|pornography|explicit|intimate)\b/i,
    media: /\b(?:photos?|pics?|pictures?|images?|videos?|clips?|snaps?)\b/i,
    request: /\b(?:send|share|trade|swap|buy|sell|upload|download|exchange|request)\b/i,
    secrecy: /\b(?:secret|secretly|privately|quietly|don.?t\s+tell)\b/i,
    contact: /\b(?:dm\s+me|pm\s+me|private\s+message|add\s+me)\b/i,
    coercion: /\b(?:blackmail|extort|extortion|threaten|threatened|threatening)\b/i,
    direct: /\b(?:csam|csae|child\s+sexual\s+abuse|child\s+sexual\s+exploitation)\b/i
  }.freeze

  def self.hold?(original)
    return true unless original.is_a?(String) && original.valid_encoding? && original.bytesize <= MAX_BYTES
    text = original.encode('UTF-8').unicode_normalize(:nfkc).gsub(/[\u200B-\u200D\uFEFF]/, '')
    h = PATTERNS.transform_values { |pattern| pattern.match?(text) }
    # Pentagonal OR comb: one output. Invalid input is held above.
    h[:direct] ||
      (h[:age] && (h[:sexual] || h[:coercion])) ||
      (h[:age] && ((h[:secrecy] && h[:contact]) || (h[:media] && h[:request]))) ||
      (h[:sexual] && h[:coercion])
  rescue StandardError
    true
  end

  def self.public_text(original)
    hold?(original) ? '' : original
  end
end