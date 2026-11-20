# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe DiscordChannel do
  let(:project) { create(:project, enabled_module_names: %i[discord_notifications]) }

  subject(:channel) { build(:discord_channel, project:) }

  describe "validations" do
    it "is valid with a Discord webhook URL and events" do
      expect(channel).to be_valid
    end

    it "rejects a non-Discord URL" do
      channel.webhook_url = "https://example.com/api/webhooks/123/token"

      expect(channel).not_to be_valid
      expect(channel.errors[:webhook_url]).to be_present
    end

    it "rejects a Discord URL without a webhook path" do
      channel.webhook_url = "https://discord.com/channels/123/456"

      expect(channel).not_to be_valid
      expect(channel.errors[:webhook_url]).to be_present
    end

    it "requires at least one event" do
      channel.events = []

      expect(channel).not_to be_valid
      expect(channel.errors[:events]).to be_present
    end

    it "rejects unknown events" do
      channel.events = ["work_package:created", "unknown:event"]

      expect(channel).not_to be_valid
      expect(channel.errors[:events]).to be_present
    end

    it "normalizes blank and duplicate events" do
      channel.events = [" work_package:created ", "", "work_package:created"]

      expect(channel).to be_valid
      expect(channel.events).to eq(["work_package:created"])
    end
  end

  describe "#subscribed_to_any?" do
    it "matches when at least one event is selected" do
      channel.events = [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]

      expect(channel.subscribed_to_any?(["work_package:updated", "work_package:status_changed"])).to be(true)
    end

    it "does not match unrelated events" do
      channel.events = [DiscordIntegration::Events::WIKI_PAGE_UPDATED]

      expect(channel.subscribed_to_any?(["work_package:updated"])).to be(false)
    end
  end

  describe "#masked_webhook_url" do
    it "hides the webhook token" do
      channel.webhook_url = "https://discord.com/api/webhooks/123456/secret-token"

      expect(channel.masked_webhook_url).to eq("https://discord.com/api/webhooks/123456/…")
      expect(channel.masked_webhook_url).not_to include("secret-token")
    end
  end

  describe "project association" do
    it "adds discord_channels to Project" do
      expect(project).to respond_to(:discord_channels)
    end
  end
end
