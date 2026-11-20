# frozen_string_literal: true

module OpenProject
  module Discord
    module Patches
      module ProjectPatch
        def self.included(receiver)
          receiver.class_eval do
            has_many :discord_channels,
                     class_name: "DiscordChannel",
                     dependent: :destroy,
                     inverse_of: :project
          end
        end
      end
    end
  end
end
