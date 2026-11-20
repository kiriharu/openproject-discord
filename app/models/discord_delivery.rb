# frozen_string_literal: true

class DiscordDelivery < ApplicationRecord
  belongs_to :discord_channel

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(success: false) }
end
