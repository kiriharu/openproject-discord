# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe DiscordIntegration::WebhookClient do
  let(:url) { "https://discord.com/api/webhooks/123456/test-token" }
  let(:payload) { { "content" => "Hello" } }

  subject(:client) { described_class.new(url:) }

  it "reports a successful delivery" do
    stub_request(:post, url).to_return(status: 204)

    response = client.deliver(payload)

    expect(response).to be_success
    expect(response.status).to eq(204)
    expect(response).not_to be_retryable
  end

  it "marks 429 responses as retryable" do
    stub_request(:post, url).to_return(status: 429, body: "rate limited")

    response = client.deliver(payload)

    expect(response).not_to be_success
    expect(response).to be_retryable
    expect(response.error).to include("429")
  end

  it "marks 5xx responses as retryable" do
    stub_request(:post, url).to_return(status: 503, body: "unavailable")

    expect(client.deliver(payload)).to be_retryable
  end

  it "does not retry 4xx responses" do
    stub_request(:post, url).to_return(status: 404, body: "unknown webhook")

    response = client.deliver(payload)

    expect(response).not_to be_success
    expect(response).not_to be_retryable
  end

  it "marks network errors as retryable" do
    stub_request(:post, url).to_raise(Errno::ECONNREFUSED)

    response = client.deliver(payload)

    expect(response).not_to be_success
    expect(response).to be_retryable
    expect(response.error).to include("ECONNREFUSED")
  end

  it "sends the payload as JSON" do
    stub = stub_request(:post, url)
             .with(body: payload.to_json, headers: { "Content-Type" => "application/json" })
             .to_return(status: 204)

    client.deliver(payload)

    expect(stub).to have_been_requested
  end
end
