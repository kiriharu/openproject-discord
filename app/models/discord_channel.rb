# frozen_string_literal: true

require "uri"

class DiscordChannel < ApplicationRecord
  ALLOWED_HOSTS = %w[
    discord.com
    www.discord.com
    discordapp.com
    www.discordapp.com
    ptb.discord.com
    canary.discord.com
  ].freeze

  WEBHOOK_PATH = %r{\A/api/(?:v\d+/)?webhooks/\d+/[A-Za-z0-9._-]+\z}

  belongs_to :project
  has_many :discord_deliveries, dependent: :delete_all

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project_id) { where(project_id:) }

  validates :name, presence: true, length: { maximum: 255 }
  validates :webhook_url, presence: true
  validates :events, presence: true
  validate :webhook_url_must_be_a_discord_webhook
  validate :events_must_be_known

  before_validation :normalize_events
  before_validation :strip_attributes

  def self.subscribed_to(event_names)
    wanted = Array(event_names).map(&:to_s)

    enabled.select do |channel|
      channel.subscribed_to_any?(wanted)
    end
  end

  def subscribed_to_any?(event_names)
    (Array(events).map(&:to_s) & Array(event_names).map(&:to_s)).any?
  end

  def event_labels
    Array(events).filter_map { |event| DiscordIntegration::Events.label(event) }
  end

  def masked_webhook_url
    uri = URI.parse(webhook_url.to_s)
    path = uri.path.sub(%r{(/api/(?:v\d+/)?webhooks/\d+/).*\z}, '\1…')

    "#{uri.scheme}://#{uri.host}#{path}"
  rescue URI::InvalidURIError
    "…"
  end

  def record_delivery!(event_names:, success:, status_code: nil, error_message: nil, response_body: nil)
    discord_deliveries.create!(
      event_names: Array(event_names).join(", "),
      success:,
      status_code:,
      error_message: error_message.to_s.truncate(4_000),
      response_body: response_body.to_s.truncate(4_000)
    )

    # Delivery logs are diagnostic only. Keep the table bounded without a cron job.
    overflow_ids = discord_deliveries.order(created_at: :desc).offset(200).pluck(:id)
    discord_deliveries.where(id: overflow_ids).delete_all if overflow_ids.any?
  rescue StandardError => e
    Rails.logger.warn("[OpenProject Discord] Could not store delivery log: #{e.class}: #{e.message}")
  end

  private

  def normalize_events
    self.events = Array(events)
                    .map { |event| event.to_s.strip }
                    .reject(&:blank?)
                    .uniq
  end

  def strip_attributes
    self.name = name.to_s.strip
    self.webhook_url = webhook_url.to_s.strip
    self.username = username.to_s.strip.presence
  end

  def webhook_url_must_be_a_discord_webhook
    uri = URI.parse(webhook_url.to_s)

    valid = uri.is_a?(URI::HTTPS) &&
            ALLOWED_HOSTS.include?(uri.host.to_s.downcase) &&
            uri.path.match?(WEBHOOK_PATH)

    return if valid

    errors.add(:webhook_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:webhook_url, :invalid)
  end

  def events_must_be_known
    unknown = Array(events).map(&:to_s) - DiscordIntegration::Events.all
    return if unknown.empty?

    errors.add(:events, :inclusion, value: unknown.join(", "))
  end
end
