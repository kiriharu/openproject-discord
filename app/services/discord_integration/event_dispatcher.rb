# frozen_string_literal: true

module DiscordIntegration
  # Finds the Discord channels interested in an event and enqueues one delivery
  # job per channel. All work that can fail is isolated so that a Discord
  # problem never breaks the OpenProject transaction that produced the event.
  class EventDispatcher
    class << self
      def work_package_journal(journal)
        work_package = journal.journable
        return unless work_package

        event_names = Events.work_package_event_names(journal)
        return if event_names.empty?

        enqueue(
          project_id: work_package.project_id,
          event_names:,
          payload: PayloadBuilder.work_package(work_package, journal, event_names)
        )
      rescue StandardError => e
        log_error("work package journal #{journal&.id}", e)
      end

      def wiki_page_journal(journal)
        page = journal.journable
        return unless page

        event_names = Events.wiki_page_event_names(journal)
        return if event_names.empty?

        enqueue(
          project_id: page.wiki.project_id,
          event_names:,
          payload: PayloadBuilder.wiki_page(page, journal, event_names)
        )
      rescue StandardError => e
        log_error("wiki page journal #{journal&.id}", e)
      end

      def work_package_deleted(snapshot)
        return if snapshot.blank?

        enqueue(
          project_id: snapshot["project_id"],
          event_names: [Events::WORK_PACKAGE_DELETED],
          payload: PayloadBuilder.deleted_work_package(snapshot)
        )
      rescue StandardError => e
        log_error("deleted work package #{snapshot&.dig('resource_id')}", e)
      end

      def wiki_page_deleted(snapshot)
        return if snapshot.blank?

        enqueue(
          project_id: snapshot["project_id"],
          event_names: [Events::WIKI_PAGE_DELETED],
          payload: PayloadBuilder.deleted_wiki_page(snapshot)
        )
      rescue StandardError => e
        log_error("deleted wiki page #{snapshot&.dig('resource_id')}", e)
      end

      private

      def enqueue(project_id:, event_names:, payload:)
        return unless Settings.enabled?
        return if project_id.blank?

        project = Project.find_by(id: project_id)
        return unless project&.module_enabled?(:discord_notifications)

        channels = DiscordChannel
                     .enabled
                     .for_project(project_id)
                     .select { |channel| channel.subscribed_to_any?(event_names) }

        if channels.empty?
          Rails.logger.info(
            "[OpenProject Discord] No matching channels for #{event_names.join(', ')} " \
            "in project #{project.identifier}"
          )
          return
        end

        payload_json = JSON.generate(payload)
        channels.each do |channel|
          DiscordNotificationJob.perform_later(channel.id, event_names, payload_json)
        end

        Rails.logger.info(
          "[OpenProject Discord] Enqueued #{channels.size} notification(s) for " \
          "#{event_names.join(', ')} in project #{project.identifier}"
        )
      end

      def log_error(context, error)
        Rails.logger.error(
          "[OpenProject Discord] Failed to dispatch #{context}: #{error.class}: #{error.message}"
        )
      end
    end
  end
end
