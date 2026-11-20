# frozen_string_literal: true

module DiscordIntegration
  # Builds absolute OpenProject links outside of a request cycle (for jobs and
  # callbacks). Falls back to Setting.host_name when static routing helpers are
  # not available in a minimal test environment.
  module UrlBuilder
    module_function

    def work_package(work_package)
      helpers.work_package_url(work_package)
    rescue StandardError
      manual_url("/work_packages/#{work_package.id}")
    end

    def wiki_page(page)
      helpers.project_wiki_url(page.wiki.project, page.slug)
    rescue StandardError
      manual_url("/projects/#{page.wiki.project_id}/wiki/#{page.slug}")
    end

    def helpers
      @helpers ||= OpenProject::StaticRouting::StaticUrlHelpers.new
    end

    def manual_url(path)
      host = begin
        ::Setting.host_name
      rescue StandardError
        "localhost"
      end
      protocol = begin
        ::Setting.protocol
      rescue StandardError
        "http"
      end

      "#{protocol}://#{host}#{path}"
    end
  end
end
