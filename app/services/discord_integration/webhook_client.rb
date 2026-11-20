# frozen_string_literal: true

require "net/http"
require "openssl"
require "json"

module DiscordIntegration
  # Minimal Discord webhook client. It deliberately uses only the Ruby standard
  # library so the plugin does not add a runtime gem dependency to OpenProject.
  class WebhookClient
    class Error < StandardError; end
    class RetryableError < Error; end

    Response = Struct.new(:success, :status, :body, :error, :retryable, keyword_init: true) do
      def success?
        !!success
      end

      def retryable?
        !!retryable
      end
    end

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 15

    def initialize(url:, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
      @url = url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def deliver(payload)
      uri = URI.parse(@url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.write_timeout = @read_timeout if http.respond_to?(:write_timeout=)

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "OpenProject-Discord/#{OpenProject::Discord::VERSION}"
      request.body = JSON.generate(payload)

      response = http.request(request)
      build_response(response)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
           Errno::ENETUNREACH, SocketError, OpenSSL::SSL::SSLError => e
      Response.new(success: false, status: nil, body: nil, error: "#{e.class}: #{e.message}", retryable: true)
    rescue URI::InvalidURIError => e
      Response.new(success: false, status: nil, body: nil, error: "#{e.class}: #{e.message}", retryable: false)
    end

    private

    def build_response(response)
      status = response.code.to_i
      body = response.body.to_s.truncate(4_000)
      success = status.between?(200, 299)
      retryable = status == 429 || status.between?(500, 599)

      error = success ? nil : "Discord webhook returned HTTP #{status}"
      error = "#{error}: #{body}" if body.present?

      Response.new(success:, status:, body:, error:, retryable:)
    end
  end
end
