# frozen_string_literal: true

FactoryBot.define do
  factory :discord_channel do
    project
    sequence(:name) { |n| "#project-updates-#{n}" }
    sequence(:webhook_url) do |n|
      "https://discord.com/api/webhooks/#{n}#{Time.current.to_i}/test-token-#{n}"
    end
    enabled { true }
    events { DiscordIntegration::Events.defaults }

    trait :work_packages_only do
      events do
        [
          DiscordIntegration::Events::WORK_PACKAGE_CREATED,
          DiscordIntegration::Events::WORK_PACKAGE_UPDATED
        ]
      end
    end

    trait :wiki_only do
      events do
        [
          DiscordIntegration::Events::WIKI_PAGE_CREATED,
          DiscordIntegration::Events::WIKI_PAGE_UPDATED
        ]
      end
    end

    trait :disabled do
      enabled { false }
    end
  end
end
