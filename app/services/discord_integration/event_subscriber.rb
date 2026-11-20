# frozen_string_literal: true

module DiscordIntegration
  # Subscribes to OpenProject's aggregated journal events.
  #
  # OpenProject aggregates journal notifications for a short interval. The
  # journal therefore already contains the final state of the resource and
  # whether it was created or updated.
  module EventSubscriber
    class << self
      def subscribe!
        return if @subscribed

        subscribe(OpenProject::Events::AGGREGATED_WORK_PACKAGE_JOURNAL_READY) do |payload|
          EventDispatcher.work_package_journal(payload[:journal])
        end

        subscribe(OpenProject::Events::AGGREGATED_WIKI_JOURNAL_READY) do |payload|
          EventDispatcher.wiki_page_journal(payload[:journal])
        end

        @subscribed = true
      end

      def reset!
        @subscribed = false
      end

      private

      def subscribe(event, &block)
        OpenProject::Notifications.subscribe(event) do |payload|
          block.call(payload)
        rescue StandardError => e
          Rails.logger.error(
            "[OpenProject Discord] Notification handler for #{event} failed: #{e.class}: #{e.message}"
          )
        end
      end
    end
  end
end
