# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe DiscordIntegration::EventDispatcher do
  let(:project) { create(:project, enabled_module_names: %i[discord_notifications]) }
  let(:work_package) { create(:work_package, project:) }
  let(:journal) do
    instance_double(
      Journal,
      journable: work_package,
      initial?: false,
      details: { status_id: [1, 2] },
      notes: nil,
      user: work_package.author,
      created_at: Time.current,
      id: 123
    )
  end

  before do
    allow(DiscordIntegration::Settings).to receive(:enabled?).and_return(true)
    allow(DiscordIntegration::PayloadBuilder).to receive(:work_package).and_return("embeds" => [])
  end

  it "enqueues a job for a channel subscribed to a produced event" do
    channel = create(
      :discord_channel,
      project:,
      events: [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
    )

    expect(DiscordNotificationJob).to receive(:perform_later)
      .with(channel.id,
            include(DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED),
            anything)
      .and_return(true)

    described_class.work_package_journal(journal)
  end

  it "does not enqueue a job for unrelated event selections" do
    create(:discord_channel, project:, events: [DiscordIntegration::Events::WIKI_PAGE_UPDATED])

    expect(DiscordNotificationJob).not_to receive(:perform_later)

    described_class.work_package_journal(journal)
  end

  it "does not enqueue a job for a disabled channel" do
    create(
      :discord_channel,
      project:,
      enabled: false,
      events: [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
    )

    expect(DiscordNotificationJob).not_to receive(:perform_later)

    described_class.work_package_journal(journal)
  end

  it "does not enqueue a job when the project module is disabled" do
    project.update!(enabled_module_names: [])
    create(
      :discord_channel,
      project:,
      events: [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
    )

    expect(DiscordNotificationJob).not_to receive(:perform_later)

    described_class.work_package_journal(journal)
  end

  it "does not enqueue a job when the global switch is off" do
    allow(DiscordIntegration::Settings).to receive(:enabled?).and_return(false)
    create(
      :discord_channel,
      project:,
      events: [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
    )

    expect(DiscordNotificationJob).not_to receive(:perform_later)

    described_class.work_package_journal(journal)
  end

  it "swallows builder errors so OpenProject transactions are not affected" do
    create(
      :discord_channel,
      project:,
      events: [DiscordIntegration::Events::WORK_PACKAGE_STATUS_CHANGED]
    )
    allow(DiscordIntegration::PayloadBuilder).to receive(:work_package).and_raise("boom")

    expect { described_class.work_package_journal(journal) }.not_to raise_error
  end
end
