# frozen_string_literal: true

module DiscordIntegration
  # Reads the global plugin settings and applies safe defaults.
  module Settings
    DEFAULTS = {
      "enabled" => true,
      "username" => "OpenProject",
      "avatar_url" => "",
      "include_private_notes" => false,
      "include_wiki_excerpt" => false
    }.freeze

    class << self
      def current
        DEFAULTS
          .merge((::Setting.plugin_openproject_discord || {}).to_h.stringify_keys)
          .stringify_keys
      rescue StandardError
        DEFAULTS.dup
      end

      def enabled?
        boolean(current["enabled"])
      end

      def username
        current["username"].presence || DEFAULTS["username"]
      end

      def avatar_url
        current["avatar_url"].presence
      end

      def include_private_notes?
        boolean(current["include_private_notes"])
      end

      def include_wiki_excerpt?
        boolean(current["include_wiki_excerpt"])
      end

      private

      def boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
