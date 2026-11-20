# frozen_string_literal: true

class CreateDiscordDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :discord_deliveries do |t|
      t.references :discord_channel, null: false, foreign_key: true, index: true
      t.string :event_names, null: false, default: ""
      t.boolean :success, null: false, default: false
      t.integer :status_code
      t.text :error_message
      t.text :response_body

      t.timestamps null: false

      t.index %i[discord_channel_id created_at]
    end
  end
end
