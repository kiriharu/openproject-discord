# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe DiscordNotificationJob do
  let(:project) { create(:project, enabled_module_names: %i[discord_notifications]) }
  let(:channel) do
    create(
      :discord_channel,
      project:,
      username: "Apollo Bot",
      events: [DiscordIntegration::Events::WORK_PACKAGE_UPDATED]
    )
  end
  let(:event_names) { [DiscordIntegration::Events::WORK_PACKAGE_UPDATED] }
  let(:payload) do
    {
      "username" => "OpenProject",
      "embeds" => [{ "title" => "Hello" }],
      "allowed_mentions" => { "parse" => [] }
    }
  end

  before do
    allow(DiscordIntegration::Settings).to receive(:username).and_return("OpenProject")
    allow(DiscordIntegration::Settings).to receive(:avatar_url).and_return(nil)
  end

  it "posts the payload, applies the channel name and logs the delivery" do
    stub = stub_request(:post, channel.webhook_url)
             .with(body: hash_including("username" => "Apollo Bot"))
             .to_return(status: 204)

    expect do
      described_class.perform_now(channel.id, event_names, payload.to_json)
    end.to change(DiscordDelivery, :count).by(1)

    expect(stub).to have_been_requested
    expect(DiscordDelivery.last).to be_success
  end

  it "does not send when the channel is disabled" do
    channel.update!(enabled: false)
    stub = stub_request(:post, channel.webhook_url).to_return(status: 204)

    described_class.perform_now(channel.id, event_names, payload.to_json)

    expect(stub).not_to have_been_requested
  end

  it "does not send when the event is no longer selected" do
    channel.update!(events: [DiscordIntegration::Events::WIKI_PAGE_UPDATED])
    stub = stub_request(:post, channel.webhook_url).to_return(status: 204)

    described_class.perform_now(channel.id, event_names, payload.to_json)

    expect(stub).not_to have_been_requested
  end

  it "raises a retryable error for 429 responses" do
    stub_request(:post, channel.webhook_url).to_return(status: 429, body: "rate limited")

    expect do
      described_class.perform_now(channel.id, event_names, payload.to_json)
    end.to raise_error(DiscordIntegration::WebhookClient::RetryableError)
  end
end
