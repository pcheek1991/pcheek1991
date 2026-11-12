# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
# Rails integration EXAMPLE, not ready for unsupervised production deployment.
# Requires Post(public_text, hold), SafetyReview(encrypted original_text),
# SafetyAudit(event_id, hold, policy_version), and configured ActiveRecord encryption.
class PostsController < ApplicationController
  def create
    original = params.require(:post).require(:text)
    return head(:bad_request) unless original.is_a?(String)
    hold = SingleBitGate.hold?(original)  # THE SINGLE PUBLIC-GATE BOOLEAN
    post = nil
    Post.transaction do
      post = Post.create!(public_text: hold ? '' : original, hold: hold)
      SafetyReview.create!(post: post, original_text: original) if hold
      SafetyAudit.create!(post: post, event_id: SecureRandom.uuid,
                          hold: hold, policy_version: '3.0.0-single-bit')
    end
    render json: { accepted: true, id: post.id, public_text: post.public_text }, status: :accepted
  rescue ActionController::ParameterMissing
    head :bad_request
  rescue StandardError
    Rails.logger.error('Safety write failure (raw text suppressed from logs)')
    head :service_unavailable
  end
end