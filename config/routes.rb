# frozen_string_literal: true

Rails.application.routes.draw do
  resources :projects, only: [] do
    namespace :settings do
      resources :discord_channels,
                controller: "/discord_integration/project_settings/channels",
                path: "discord",
                except: %i[show] do
        member do
          post :test_message
        end
      end
    end
  end
end
