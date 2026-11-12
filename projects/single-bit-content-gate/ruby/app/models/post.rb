# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
class Post < ApplicationRecord
  has_one :safety_review, dependent: :restrict_with_exception
  has_one :safety_audit, dependent: :restrict_with_exception
end