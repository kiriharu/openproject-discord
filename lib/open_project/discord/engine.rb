# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module Discord
    class Engine < ::Rails::Engine
      engine_name :openproject_discord

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-discord",
               author_url: "https://github.com/openproject/openproject-discord",
               requires_openproject: ">= 16.0.0",
               settings: {
                 default: {
                   "enabled" => true,
                   "username" => "OpenProject",
                   "avatar_url" => "",
                   "include_private_notes" => false,
                   "include_wiki_excerpt" => false
                 },
                 partial: "settings/openproject_discord",
                 menu_item: :discord_integration
               } do
        project_module :discord_notifications do
          permission :manage_discord_notifications,
                     {
                       "discord_integration/project_settings/channels": %i[
                         index new create edit update destroy test_message
                       ]
                     },
                     permissible_on: :project,
                     require: :member
        end

        menu :admin_menu,
             :discord_integration,
             { controller: "/admin/settings", action: "show_plugin", id: "openproject_discord" },
             parent: :admin_integrations,
             if: ->(_) { User.current.admin? },
             caption: :"discord.admin.menu_title"

        menu :project_menu,
             :discord_settings,
             { controller: "/discord_integration/project_settings/channels", action: :index },
             parent: :settings,
             after: :settings_modules,
             caption: :"discord.project_settings.menu_title",
             if: ->(project) {
               project.module_enabled?(:discord_notifications) &&
                 User.current.allowed_in_project?(:manage_discord_notifications, project)
             }
      end

      patches %i[Project WorkPackage WikiPage]

      initializer "openproject_discord.subscribe_to_notifications" do |app|
        app.config.after_initialize do
          ::DiscordIntegration::EventSubscriber.subscribe!
        end
      end

    end
  end
end
