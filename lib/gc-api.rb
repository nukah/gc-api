require_relative 'entities/entity'
require_relative 'entities/calendar_list'
require_relative 'entities/calendar'
require_relative 'entities/person'
require_relative 'entities/recurrence'
require_relative 'entities/event'
require_relative 'entities/event_time'
require 'signet/oauth_2/client'
require 'faraday'
require 'typhoeus/adapters/faraday'
require 'json'

module GCAPI
  class GoogleCalendarError < Exception; end
  class GoogleCalendarAttributesError < GoogleCalendarError; end

  class API
    GOOGLE_CALENDAR_API ||= "https://www.googleapis.com/calendar/v3"
    GOOGLE_AUTH_ENDPOINT ||= "https://accounts.google.com/o/oauth2/auth"
    GOOGLE_AUTH_TOKEN_ENDPOINT ||= "https://www.googleapis.com/oauth2/v3/token"
    GOOGLE_CALENDAR_SCOPE ||= "https://www.googleapis.com/auth/calendar"

    def initialize(client_id, client_secret, redirect_uri)
      @connection = Faraday.new(GOOGLE_CALENDAR_API) do |req|
        req.request :url_encoded
        req.adapter :typhoeus
      end

      @authorization = Signet::OAuth2::Client.new(
        authorization_uri: GOOGLE_AUTH_ENDPOINT,
        token_credential_uri: GOOGLE_AUTH_TOKEN_ENDPOINT,
        client_id: client_id,
        client_secret: client_secret,
        scope: GOOGLE_CALENDAR_SCOPE,
        redirect_uri: redirect_uri
      )
    end
    def authorization_url
      @authorization.authorization_uri.to_s
    end

    def access_token(code)
      @authorization.code = code
      @authorization.fetch_access_token!
    end

    def active?
      !@authorization.expired?
    end

    def client_id
      @authorization.client_id
    end

    def request(method, path, data = nil)
      path = path.to_s
      method = method
      raise GoogleCalendarAttributesError.new("Wrong HTTP Method") unless [:get, :post, :put, :delete].include?(method.to_sym)
      raise GoogleCalendarError.new("Access token not present!") unless @authorization.access_token
      raise GoogleCalendarError.new("Access token expired!") if @authorization.expired?

      refresh_token if @authorization.expires_in < 500

      response = @connection.send(method.to_sym) do |req|
        req.url path
        req.headers['Authorization'] = Signet::OAuth2.generate_bearer_authorization_header(@authorization.access_token)
        req.headers['Content-Type'] = 'application/json'

        req.body = Yajl::Encoder.encode(data) if data
      end
      puts response.body
      begin
        result = JSON.parse(response.body, symbolize_names: true)
      rescue Exception => e
        #raise GoogleCalendarError.new("Error on requesting content!")
        result = nil
      end
      result
    end

    def refresh_token
      @authorization.refresh!
    end

    def to_s
      "Authorization: #{active?}. Access token present: #{@authorization.access_token}. Time left: #{@authorization.expires_in}"
    end

    def inspect
      to_s
    end
  end
end