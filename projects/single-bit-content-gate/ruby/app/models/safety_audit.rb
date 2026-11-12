# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
class SafetyAudit < ApplicationRecord
  belongs_to :post
  # Metadata only. No text, URL, username, or sensitive identifiers.
end