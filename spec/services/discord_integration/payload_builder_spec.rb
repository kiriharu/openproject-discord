# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe DiscordIntegration::PayloadBuilder do
  let(:project) { create(:project, name: "Apollo", enabled_module_names: %i[discord_notifications]) }
  let(:channel) { build(:discord_channel, project:, name: "#apollo") }

  before do
    allow(Setting).to receive(:plugin_openproject_discord).and_return(
      "enabled" => true,
      "username" => "OpenProject",
      "include_private_notes" => false,
      "include_wiki_excerpt" => false
    )
  end

  describe ".work_package" do
    let(:author) { create(:user, firstname: "Ada", lastname: "Lovelace") }
    let(:assignee) { create(:user, firstname: "Grace", lastname: "Hopper") }
    let(:work_package) do
      create(:work_package, project:, author:, assigned_to: assignee, subject: "Fix the rocket")
    end
    let(:journal) do
      instance_double(
        Journal,
        journable: work_package,
        initial?: false,
        details: { status_id: [1, 2], subject: ["Old", "Fix the rocket"] },
        notes: "Ready for review",
        internal?: false,
        user: author,
        created_at: Time.zone.parse("2026-11-20 10:00:00")
      )
    end

    it "builds one embed with project, assignee and changed fields" do
      payload = described_class.work_package(
        work_package,
        journal,
        [DiscordIntegration::Events::WORK_PACKAGE_UPDATED,
         DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
      )

      embed = payload.fetch("embeds").first
      field_values = embed.fetch("fields").to_h { |field| [field["name"], field["value"]] }

      expect(payload["username"]).to eq("OpenProject")
      expect(embed["title"]).to include("Fix the rocket")
      expect(embed["url"]).to include("/work_packages/#{work_package.id}")
      expect(embed["description"]).to eq("Ready for review")
      expect(field_values["Project"]).to eq("Apollo")
      expect(field_values["Assignee"]).to include("Grace")
      expect(field_values["Changes"]).to include("Status")
      expect(payload.dig("allowed_mentions", "parse")).to eq([])
    end

    it "does not include an internal note by default" do
      allow(journal).to receive(:internal?).and_return(true)

      payload = described_class.work_package(
        work_package,
        journal,
        [DiscordIntegration::Events::WORK_PACKAGE_COMMENTED]
      )

      expect(payload.dig("embeds", 0, "description")).not_to eq("Ready for review")
    end
  end

  describe ".deleted_work_package" do
    it "builds a deletion embed from a snapshot" do
      snapshot = {
        "title" => "#42 Old task",
        "url" => "https://openproject.example.com/work_packages/42",
        "project_name" => "Apollo",
        "type_name" => "Task",
        "status_name" => "Closed",
        "actor_name" => "Ada Lovelace",
        "occurred_at" => "2026-11-20T10:00:00Z"
      }

      payload = described_class.deleted_work_package(snapshot)

      expect(payload.dig("embeds", 0, "title")).to eq("#42 Old task")
      expect(payload.dig("embeds", 0, "description")).to eq(I18n.t("discord.messages.work_package_deleted"))
      expect(payload.dig("embeds", 0, "color")).to eq(described_class::COLORS[:deleted])
    end
  end

  describe ".test_message" do
    it "contains a test title and channel information" do
      payload = described_class.test_message(channel:)
      embed = payload.fetch("embeds").first
      values = embed.fetch("fields").to_h { |field| [field["name"], field["value"]] }

      expect(embed["title"]).to eq(I18n.t("discord.messages.test_title"))
      expect(values["Project"]).to eq("Apollo")
      expect(values["Channel"]).to eq("#apollo")
    end
  end

  describe ".apply_channel_overrides" do
    it "uses the channel-specific name when present" do
      channel.username = "Apollo Bot"

      payload = described_class.apply_channel_overrides({ "username" => "OpenProject" }, channel)

      expect(payload["username"]).to eq("Apollo Bot")
    end

    it "falls back to the global name" do
      channel.username = nil

      payload = described_class.apply_channel_overrides({ "username" => "Someone" }, channel)

      expect(payload["username"]).to eq("OpenProject")
    end
  end
end
