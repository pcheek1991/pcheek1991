# frozen_string_literal: true
# SPDX-License-Identifier: Unlicense
# GREENFIELD example. Do not run alongside the earlier numeric-score migrations
# without first planning a data-preserving schema migration and review of retention.
class CreateSingleBitSafetyTables < ActiveRecord::Migration[7.1]
  def change
    create_table(:posts) do |t|
      t.text :public_text, null: false, default: ''
      t.boolean :hold, null: false, default: false
      t.timestamps
    end
    create_table(:safety_reviews) do |t|
      t.references :post, null: false, index: { unique: true }, foreign_key: true
      t.text :original_text, null: false
      t.timestamps
    end
    create_table(:safety_audits) do |t|
      t.references :post, null: false, index: { unique: true }, foreign_key: true
      t.string :event_id, null: false, index: { unique: true }
      t.boolean :hold, null: false, default: false
      t.string :policy_version, null: false
      t.timestamps
    end
  end
end