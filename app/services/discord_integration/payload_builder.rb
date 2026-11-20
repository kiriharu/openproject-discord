# frozen_string_literal: true

module DiscordIntegration
  # Converts OpenProject resources/journals into Discord webhook payloads.
  #
  # The payload is stored as JSON in the job arguments, so this class must only
  # return JSON-compatible values (strings, numbers, arrays and hashes).
  class PayloadBuilder
    COLORS = {
      created: 0x2ECC71,
      updated: 0x3498DB,
      status_changed: 0xF1C40F,
      assignee_changed: 0x9B59B6,
      commented: 0xE67E22,
      deleted: 0xE74C3C,
      test: 0x5865F2
    }.freeze

    class << self
      def work_package(work_package, journal, event_names)
        action = primary_action(event_names)
        project = work_package.project
        notes = public_notes(journal)
        changes = change_labels(journal.details)

        fields = [
          field(I18n.t("discord.fields.project"), project&.name),
          field(I18n.t("discord.fields.type"), work_package.type&.name),
          field(I18n.t("discord.fields.status"), work_package.status&.name),
          field(I18n.t("discord.fields.assignee"), principal_name(work_package.assigned_to)),
          field(I18n.t("discord.fields.priority"), work_package.priority&.name),
          field(I18n.t("discord.fields.author"), user_name(work_package.author)),
          field(I18n.t("discord.fields.changed_by"), user_name(journal.user)),
          field(I18n.t("discord.fields.changes"), changes.join(", "))
        ]

        description = notes.presence
        description ||= I18n.t("discord.messages.changes", fields: changes.join(", ")) if changes.any?

        embed_payload(
          action:,
          title: "##{display_id(work_package)} #{work_package.subject}",
          url: UrlBuilder.work_package(work_package),
          description:,
          fields:,
          occurred_at: journal.created_at
        )
      end

      def wiki_page(page, journal, event_names)
        action = primary_action(event_names)
        project = page.wiki.project
        excerpt = wiki_excerpt(page, journal)
        changes = change_labels(journal.details)

        fields = [
          field(I18n.t("discord.fields.project"), project&.name),
          field(I18n.t("discord.fields.page"), page.title),
          field(I18n.t("discord.fields.version"), page.version.to_s),
          field(I18n.t("discord.fields.author"), user_name(page.author)),
          field(I18n.t("discord.fields.changed_by"), user_name(journal.user)),
          field(I18n.t("discord.fields.changes"), changes.join(", "))
        ]

        description = excerpt.presence
        description ||= I18n.t("discord.messages.changes", fields: changes.join(", ")) if changes.any?

        embed_payload(
          action:,
          title: page.title,
          url: UrlBuilder.wiki_page(page),
          description:,
          fields:,
          occurred_at: journal.created_at
        )
      end

      def work_package_snapshot(work_package)
        {
          "resource_type" => "work_package",
          "resource_id" => work_package.id,
          "project_id" => work_package.project_id,
          "project_name" => work_package.project&.name,
          "title" => "##{display_id(work_package)} #{work_package.subject}",
          "url" => UrlBuilder.work_package(work_package),
          "actor_name" => current_user_name,
          "type_name" => work_package.type&.name,
          "status_name" => work_package.status&.name,
          "occurred_at" => Time.current.iso8601
        }
      end

      def wiki_page_snapshot(page)
        {
          "resource_type" => "wiki_page",
          "resource_id" => page.id,
          "project_id" => page.wiki.project_id,
          "project_name" => page.wiki.project&.name,
          "title" => page.title,
          "url" => UrlBuilder.wiki_page(page),
          "actor_name" => current_user_name,
          "version" => page.version,
          "occurred_at" => Time.current.iso8601
        }
      end

      def deleted_work_package(snapshot)
        fields = [
          field(I18n.t("discord.fields.project"), snapshot["project_name"]),
          field(I18n.t("discord.fields.type"), snapshot["type_name"]),
          field(I18n.t("discord.fields.status"), snapshot["status_name"]),
          field(I18n.t("discord.fields.deleted_by"), snapshot["actor_name"])
        ]

        embed_payload(
          action: :deleted,
          title: snapshot["title"],
          url: nil,
          description: I18n.t("discord.messages.work_package_deleted"),
          fields:,
          occurred_at: snapshot["occurred_at"]
        )
      end

      def deleted_wiki_page(snapshot)
        fields = [
          field(I18n.t("discord.fields.project"), snapshot["project_name"]),
          field(I18n.t("discord.fields.page"), snapshot["title"]),
          field(I18n.t("discord.fields.deleted_by"), snapshot["actor_name"])
        ]

        embed_payload(
          action: :deleted,
          title: snapshot["title"],
          url: nil,
          description: I18n.t("discord.messages.wiki_page_deleted"),
          fields:,
          occurred_at: snapshot["occurred_at"]
        )
      end

      def test_message(channel: nil)
        fields = [
          field(I18n.t("discord.fields.project"), channel&.project&.name || "—"),
          field(I18n.t("discord.fields.channel"), channel&.name || "—")
        ]

        embed_payload(
          action: :test,
          title: I18n.t("discord.messages.test_title"),
          url: nil,
          description: I18n.t("discord.messages.test_description"),
          fields:,
          occurred_at: Time.current.iso8601
        )
      end

      def apply_channel_overrides(payload, channel)
        result = deep_dup(payload)
        result["username"] = channel.username.presence || Settings.username
        avatar = Settings.avatar_url
        result["avatar_url"] = avatar if avatar.present?
        result
      end

      private

      def embed_payload(action:, title:, url:, description:, fields:, occurred_at:)
        embed = {
          "title" => truncate(title.to_s, 256),
          "url" => url.presence,
          "description" => truncate(description.to_s, 4_000).presence,
          "color" => COLORS.fetch(action, COLORS[:updated]),
          "fields" => Array(fields).compact,
          "footer" => { "text" => footer_text },
          "timestamp" => timestamp(occurred_at)
        }.compact

        {
          "username" => Settings.username,
          "embeds" => [embed],
          "allowed_mentions" => { "parse" => [] }
        }
      end

      def field(name, value)
        return if value.blank?

        { "name" => truncate(name.to_s, 256), "value" => truncate(value.to_s, 1_024), "inline" => true }
      end

      def footer_text
        I18n.t("discord.messages.footer", app: "OpenProject")
      end

      def primary_action(event_names)
        names = Array(event_names).map(&:to_s)

        return :created if names.include?(Events::WORK_PACKAGE_CREATED) || names.include?(Events::WIKI_PAGE_CREATED)
        return :deleted if names.include?(Events::WORK_PACKAGE_DELETED) || names.include?(Events::WIKI_PAGE_DELETED)
        return :commented if names.include?(Events::WORK_PACKAGE_COMMENTED)
        return :status_changed if names.include?(Events::WORK_PACKAGE_STATUS_CHANGED)
        return :assignee_changed if names.include?(Events::WORK_PACKAGE_ASSIGNEE_CHANGED)

        :updated
      end

      def public_notes(journal)
        return if journal.notes.blank?
        return if journal.respond_to?(:internal?) && journal.internal? && !Settings.include_private_notes?

        truncate(journal.notes.to_s, 1_500)
      end

      def wiki_excerpt(page, journal)
        return unless Settings.include_wiki_excerpt?

        text = if journal.initial?
                 page.try(:text)
               else
                 value = journal.details[:text] || journal.details["text"]
                 Array(value).last
               end

        truncate(text.to_s, 1_000).presence
      rescue StandardError
        nil
      end

      def change_labels(details)
        keys = details.respond_to?(:keys) ? details.keys : []

        keys.filter_map do |key|
          key = key.to_s
          next if %w[id updated_at created_at lock_version].include?(key)

          if key == "text"
            I18n.t("discord.fields.content")
          else
            begin
              WorkPackage.human_attribute_name(key)
            rescue StandardError
              key.humanize
            end
          end
        end.uniq
      end

      def display_id(work_package)
        work_package.respond_to?(:display_id) ? work_package.display_id : work_package.id
      end

      def user_name(user)
        return if user.nil?

        user.respond_to?(:name) ? user.name : user.to_s
      rescue StandardError
        nil
      end

      def principal_name(principal)
        return if principal.nil?

        principal.respond_to?(:name) ? principal.name : principal.to_s
      rescue StandardError
        nil
      end

      def current_user_name
        user_name(User.current)
      rescue StandardError
        nil
      end

      def timestamp(value)
        time = value.respond_to?(:iso8601) ? value : Time.zone.parse(value.to_s)
        (time || Time.current).iso8601
      rescue StandardError
        Time.current.iso8601
      end

      def truncate(value, length)
        value.to_s.truncate(length)
      end

      def deep_dup(value)
        case value
        when Hash
          value.to_h { |key, item| [key, deep_dup(item)] }
        when Array
          value.map { |item| deep_dup(item) }
        else
          value
        end
      end
    end
  end
end
