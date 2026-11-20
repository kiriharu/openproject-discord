# frozen_string_literal: true

require "json"

class DiscordNotificationJob < ApplicationJob
  queue_as :default

  retry_on DiscordIntegration::WebhookClient::RetryableError,
           wait: :polynomially_longer,
           attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(channel_id, event_names, payload_json)
    return unless DiscordIntegration::Settings.enabled?

    channel = DiscordChannel.find_by(id: channel_id)
    return unless channel&.enabled?
    return unless channel.subscribed_to_any?(event_names)

    payload = JSON.parse(payload_json)
    payload = DiscordIntegration::PayloadBuilder.apply_channel_overrides(payload, channel)

    response = DiscordIntegration::WebhookClient
                 .new(url: channel.webhook_url)
                 .deliver(payload)

    channel.record_delivery!(
      event_names:,
      success: response.success?,
      status_code: response.status,
      error_message: response.error,
      response_body: response.body
    )

    raise DiscordIntegration::WebhookClient::RetryableError, response.error if response.retryable?
  rescue JSON::ParserError => e
    Rails.logger.error("[OpenProject Discord] Invalid payload for channel #{channel_id}: #{e.message}")
  end
end
