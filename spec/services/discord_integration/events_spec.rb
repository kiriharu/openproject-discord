# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe DiscordIntegration::Events do
  def journal(initial: false, details: {}, notes: nil)
    instance_double(Journal, initial?: initial, details:, notes:)
  end

  describe ".work_package_event_names" do
    it "returns created for an initial journal" do
      expect(described_class.work_package_event_names(journal(initial: true)))
        .to eq([described_class::WORK_PACKAGE_CREATED])
    end

    it "returns updated for a regular update" do
      expect(described_class.work_package_event_names(journal(details: { subject: ["old", "new"] })))
        .to eq([described_class::WORK_PACKAGE_UPDATED])
    end

    it "adds status changed for a status change" do
      names = described_class.work_package_event_names(journal(details: { status_id: [1, 2] }))

      expect(names).to include(
        described_class::WORK_PACKAGE_UPDATED,
        described_class::WORK_PACKAGE_STATUS_CHANGED
      )
    end

    it "adds assignee changed for an assignee change" do
      names = described_class.work_package_event_names(journal(details: { assigned_to_id: [1, 2] }))

      expect(names).to include(described_class::WORK_PACKAGE_ASSIGNEE_CHANGED)
    end

    it "adds commented when the journal has a note" do
      names = described_class.work_package_event_names(journal(notes: "Looks good"))

      expect(names).to include(described_class::WORK_PACKAGE_COMMENTED)
    end
  end

  describe ".wiki_page_event_names" do
    it "returns created for an initial journal" do
      expect(described_class.wiki_page_event_names(journal(initial: true)))
        .to eq([described_class::WIKI_PAGE_CREATED])
    end

    it "returns updated for a regular journal" do
      expect(described_class.wiki_page_event_names(journal(details: { text: ["a", "b"] })))
        .to eq([described_class::WIKI_PAGE_UPDATED])
    end
  end

  describe ".grouped" do
    it "contains work packages and wiki pages with translated labels" do
      grouped = described_class.grouped

      expect(grouped.keys).to contain_exactly("work_package", "wiki_page")
      expect(grouped["work_package"].to_h).to include(
        described_class::WORK_PACKAGE_CREATED => I18n.t("discord.events.work_package_created")
      )
    end
  end
end
