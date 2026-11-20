# frozen_string_literal: true

module DiscordIntegration
  # Central registry of events that can be selected for a Discord channel.
  #
  # A single OpenProject journal can produce several event names. For example a
  # status change also produces "work_package:updated". A channel receives one
  # message when at least one of the produced names is selected.
  module Events
    WORK_PACKAGE_CREATED = "work_package:created"
    WORK_PACKAGE_UPDATED = "work_package:updated"
    WORK_PACKAGE_STATUS_CHANGED = "work_package:status_changed"
    WORK_PACKAGE_ASSIGNEE_CHANGED = "work_package:assignee_changed"
    WORK_PACKAGE_COMMENTED = "work_package:commented"
    WORK_PACKAGE_DELETED = "work_package:deleted"

    WIKI_PAGE_CREATED = "wiki_page:created"
    WIKI_PAGE_UPDATED = "wiki_page:updated"
    WIKI_PAGE_DELETED = "wiki_page:deleted"

    GROUPS = {
      "work_package" => [
        WORK_PACKAGE_CREATED,
        WORK_PACKAGE_UPDATED,
        WORK_PACKAGE_STATUS_CHANGED,
        WORK_PACKAGE_ASSIGNEE_CHANGED,
        WORK_PACKAGE_COMMENTED,
        WORK_PACKAGE_DELETED
      ],
      "wiki_page" => [
        WIKI_PAGE_CREATED,
        WIKI_PAGE_UPDATED,
        WIKI_PAGE_DELETED
      ]
    }.freeze

    class << self
      def all
        GROUPS.values.flatten
      end

      def defaults
        all
      end

      def grouped
        GROUPS.transform_values { |events| events.map { |event| [event, label(event)] } }
      end

      def label(event)
        I18n.t("discord.events.#{event.to_s.tr(':', '_')}", default: event.to_s.humanize)
      end

      def work_package_event_names(journal)
        if journal.initial?
          [WORK_PACKAGE_CREATED]
        else
          names = [WORK_PACKAGE_UPDATED]
          names << WORK_PACKAGE_STATUS_CHANGED if detail?(journal, :status_id)
          names << WORK_PACKAGE_ASSIGNEE_CHANGED if detail?(journal, :assigned_to_id)
          names << WORK_PACKAGE_COMMENTED if journal.notes.present?
          names
        end
      end

      def wiki_page_event_names(journal)
        journal.initial? ? [WIKI_PAGE_CREATED] : [WIKI_PAGE_UPDATED]
      end

      def work_package?(event_name)
        event_name.to_s.start_with?("work_package:")
      end

      def wiki_page?(event_name)
        event_name.to_s.start_with?("wiki_page:")
      end

      private

      def detail?(journal, key)
        details = journal.details
        details.key?(key) || details.key?(key.to_s)
      rescue StandardError
        false
      end
    end
  end
end
