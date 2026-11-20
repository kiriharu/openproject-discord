# frozen_string_literal: true

module OpenProject
  module Discord
    module Patches
      # Work package creation and updates are handled by the aggregated journal
      # notification. Deletions remove their journals, so we capture a small
      # snapshot before deletion and notify after the transaction commits.
      module WorkPackagePatch
        def self.included(receiver)
          receiver.class_eval do
            before_destroy :remember_discord_deletion_snapshot
            after_destroy_commit :notify_discord_about_deletion
          end
        end

        private

        def remember_discord_deletion_snapshot
          @discord_deletion_snapshot = DiscordIntegration::PayloadBuilder.work_package_snapshot(self)
        rescue StandardError => e
          Rails.logger.warn(
            "[OpenProject Discord] Could not capture deleted work package #{id}: #{e.class}: #{e.message}"
          )
        end

        def notify_discord_about_deletion
          DiscordIntegration::EventDispatcher.work_package_deleted(@discord_deletion_snapshot)
        ensure
          @discord_deletion_snapshot = nil
        end
      end
    end
  end
end
