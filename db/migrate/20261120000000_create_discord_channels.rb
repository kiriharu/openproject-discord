# frozen_string_literal: true

class CreateDiscordChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :discord_channels do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :webhook_url, null: false
      t.string :username
      t.boolean :enabled, null: false, default: true
      t.jsonb :events, null: false, default: []

      t.timestamps null: false

      t.index %i[project_id enabled]
    end
  end
end
