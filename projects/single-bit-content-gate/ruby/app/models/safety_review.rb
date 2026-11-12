# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
class SafetyReview < ApplicationRecord
  belongs_to :post
  encrypts :original_text
  # Restrict database access to trained moderators; secure retention, audit access,
  # evidence custody and mandatory reporting are independent requirements.
end