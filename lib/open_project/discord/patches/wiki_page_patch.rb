# frozen_string_literal: true

module OpenProject
  module Discord
    module Patches
      # Wiki page creation and updates are handled by the aggregated journal
      # notification. Deletions have no usable journal, so capture a snapshot
      # before the page is removed.
      module WikiPagePatch
        def self.included(receiver)
          receiver.class_eval do
            before_destroy :remember_discord_deletion_snapshot
            after_destroy_commit :notify_discord_about_deletion
          end
        end

        private

        def remember_discord_deletion_snapshot
          @discord_deletion_snapshot = DiscordIntegration::PayloadBuilder.wiki_page_snapshot(self)
        rescue StandardError => e
          Rails.logger.warn(
            "[OpenProject Discord] Could not capture deleted wiki page #{id}: #{e.class}: #{e.message}"
          )
        end

        def notify_discord_about_deletion
          DiscordIntegration::EventDispatcher.wiki_page_deleted(@discord_deletion_snapshot)
        ensure
          @discord_deletion_snapshot = nil
        end
      end
    end
  end
end
