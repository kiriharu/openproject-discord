# frozen_string_literal: true

module DiscordIntegration
  module ProjectSettings
    class ChannelsController < ::Projects::SettingsController
      menu_item :discord_settings

      before_action :find_channel, only: %i[edit update destroy test_message]

      def index
        @channels = @project.discord_channels.order(:name, :id)
      end

      def new
        @channel = build_channel
      end

      def create
        @channel = build_channel
        @channel.assign_attributes(channel_attributes)

        if @channel.save
          flash[:notice] = I18n.t(:notice_successful_create)
          redirect_to project_settings_discord_channels_path(@project)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @channel.update(channel_attributes)
          flash[:notice] = I18n.t(:notice_successful_update)
          redirect_to project_settings_discord_channels_path(@project)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @channel.destroy
        flash[:notice] = I18n.t(:notice_successful_delete)
        redirect_to project_settings_discord_channels_path(@project), status: :see_other
      end

      def test_message
        payload = DiscordIntegration::PayloadBuilder.test_message(channel: @channel)
        payload = DiscordIntegration::PayloadBuilder.apply_channel_overrides(payload, @channel)

        response = DiscordIntegration::WebhookClient
                     .new(url: @channel.webhook_url)
                     .deliver(payload)

        @channel.record_delivery!(
          event_names: ["test"],
          success: response.success?,
          status_code: response.status,
          error_message: response.error,
          response_body: response.body
        )

        warnings = test_warnings

        if response.success?
          flash[:notice] = I18n.t("discord.project_settings.test_success")
          flash[:warning] = warnings.join(" ") if warnings.any?
        else
          flash[:error] = I18n.t("discord.project_settings.test_failure", error: response.error)
        end

        redirect_to project_settings_discord_channels_path(@project), status: :see_other
      end

      private

      def build_channel
        @project.discord_channels.new(
          enabled: true,
          events: DiscordIntegration::Events.defaults
        )
      end

      def find_channel
        @channel = @project.discord_channels.find(params[:id])
      end

      def test_warnings
        warnings = []
        unless @project.module_enabled?(:discord_notifications)
          warnings << I18n.t("discord.project_settings.warning_module_disabled")
        end
        unless DiscordIntegration::Settings.enabled?
          warnings << I18n.t("discord.project_settings.warning_global_disabled")
        end
        if Array(@channel.events).empty?
          warnings << I18n.t("discord.project_settings.warning_no_events")
        end
        warnings
      end

      def channel_attributes
        permitted = params.require(:discord_channel).permit(
          :name,
          :webhook_url,
          :username,
          :enabled,
          events: []
        )

        attributes = permitted.to_h
        attributes[:events] = Array(permitted[:events]).compact_blank
        attributes[:enabled] = ActiveModel::Type::Boolean.new.cast(attributes[:enabled])
        attributes
      end
    end
  end
end
