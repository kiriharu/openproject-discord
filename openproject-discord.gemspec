# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "open_project/discord/version"

Gem::Specification.new do |s|
  s.name        = "openproject-discord"
  s.version     = OpenProject::Discord::VERSION
  s.authors     = ["OpenProject Discord contributors"]
  s.summary     = "OpenProject Discord notifications for work packages and wiki pages"
  s.description = "Sends configurable notifications about work package and wiki page changes " \
                  "from OpenProject projects to Discord channels via webhooks."
  s.license     = "GPL-3.0-only"
  s.homepage    = "https://github.com/kiriharu/openproject-discord"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w[README.md README_RU.md CHANGELOG.md LICENSE]

  s.required_ruby_version = ">= 3.4.0"
  s.metadata["rubygems_mfa_required"] = "true"
  s.metadata["source_code_uri"] = "https://github.com/kiriharu/openproject-discord"
end
