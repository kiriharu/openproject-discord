# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Project Discord channels", type: :request do
  shared_let(:project) do
    create(:project, enabled_module_names: %i[discord_notifications work_package_tracking])
  end
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[manage_discord_notifications] })
  end

  before do
    login_as(user)
  end

  describe "GET /projects/:project_id/settings/discord" do
    it "renders the channel list" do
      create(:discord_channel, project:, name: "#updates")

      get project_settings_discord_channels_path(project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("#updates")
      expect(response.body).to include(I18n.t("discord.project_settings.title"))
    end
  end

  describe "POST /projects/:project_id/settings/discord" do
    it "creates a channel with selected events" do
      expect do
        post project_settings_discord_channels_path(project), params: {
          discord_channel: {
            name: "#builds",
            webhook_url: "https://discord.com/api/webhooks/123456/test-token",
            enabled: "1",
            events: [
              DiscordIntegration::Events::WORK_PACKAGE_CREATED,
              DiscordIntegration::Events::WIKI_PAGE_UPDATED
            ]
          }
        }
      end.to change(DiscordChannel, :count).by(1)

      expect(response).to redirect_to(project_settings_discord_channels_path(project))
      channel = DiscordChannel.last
      expect(channel.name).to eq("#builds")
      expect(channel.events).to contain_exactly(
        DiscordIntegration::Events::WORK_PACKAGE_CREATED,
        DiscordIntegration::Events::WIKI_PAGE_UPDATED
      )
    end

    it "renders validation errors for a non-Discord URL" do
      expect do
        post project_settings_discord_channels_path(project), params: {
          discord_channel: {
            name: "#bad",
            webhook_url: "https://example.com/api/webhooks/123/token",
            enabled: "1",
            events: [DiscordIntegration::Events::WORK_PACKAGE_CREATED]
          }
        }
      end.not_to change(DiscordChannel, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /projects/:project_id/settings/discord/:id" do
    let!(:channel) { create(:discord_channel, project:, name: "#old") }

    it "updates the channel and its events" do
      patch project_settings_discord_channel_path(project, channel), params: {
        discord_channel: {
          name: "#new",
          webhook_url: channel.webhook_url,
          enabled: "0",
          events: [DiscordIntegration::Events::WIKI_PAGE_CREATED]
        }
      }

      expect(response).to redirect_to(project_settings_discord_channels_path(project))
      channel.reload
      expect(channel.name).to eq("#new")
      expect(channel).not_to be_enabled
      expect(channel.events).to eq([DiscordIntegration::Events::WIKI_PAGE_CREATED])
    end
  end

  describe "DELETE /projects/:project_id/settings/discord/:id" do
    let!(:channel) { create(:discord_channel, project:) }

    it "deletes the channel" do
      expect do
        delete project_settings_discord_channel_path(project, channel)
      end.to change(DiscordChannel, :count).by(-1)

      expect(response).to redirect_to(project_settings_discord_channels_path(project))
    end
  end

  describe "POST /projects/:project_id/settings/discord/:id/test_message" do
    let!(:channel) { create(:discord_channel, project:) }

    it "sends a test message and stores a delivery log" do
      stub = stub_request(:post, channel.webhook_url).to_return(status: 204)

      expect do
        post test_message_project_settings_discord_channel_path(project, channel)
      end.to change(DiscordDelivery, :count).by(1)

      expect(stub).to have_been_requested
      expect(response).to redirect_to(project_settings_discord_channels_path(project))
      expect(flash[:notice]).to eq(I18n.t("discord.project_settings.test_success"))
    end

    it "shows Discord errors in the flash" do
      stub_request(:post, channel.webhook_url).to_return(status: 404, body: "Unknown Webhook")

      post test_message_project_settings_discord_channel_path(project, channel)

      expect(flash[:error]).to include("404")
      expect(DiscordDelivery.last).not_to be_success
    end
  end

  describe "authorization" do
    let(:outsider) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }

    it "does not allow a member without the manage permission" do
      login_as(outsider)

      get project_settings_discord_channels_path(project)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
