# Run with "bundle exec rackup"

# Setup $UAA_URL/$UAA_CA_CERT
#   source <(path/to/uaa-deployment/bin/uaa-deployment env)
#
# Create UAA client:
#   uaa create-client omniauth-login-and-uaa-api-calls -s omniauth-login-and-uaa-api-calls \
#     --authorized_grant_types authorization_code,refresh_token \
#     --scope openid,scim.read \
#     --redirect_uri http://localhost:9292/auth/cloudfoundry/callback
#
# Add user to group "scim.read":
#   uaa add-member scim.read drnic

require 'rubygems'
require 'bundler'
require 'sinatra'
require 'omniauth'
require 'omniauth-uaa-oauth2'
require 'securerandom'
require 'uaa'

UAA_URL = ENV['UAA_URL']
UAA_CLIENT = 'omniauth-login-and-uaa-api-calls'
UAA_CLIENT_SECRET = 'omniauth-login-and-uaa-api-calls'
UAA_OPTIONS = {symbolize_keys: true}
if ENV['UAA_CA_CERT_FILE'] && File.exists?(ENV['UAA_CA_CERT_FILE'])
  UAA_OPTIONS[:ssl_ca_file] = ENV['UAA_CA_CERT_FILE']
else
  UAA_OPTIONS[:skip_ssl_validation] = !!ENV['UAA_CA_CERT']
end
puts UAA_OPTIONS.to_json

class App < Sinatra::Base

  get '/' do
    if session[:user_email]
      erb :index
    else
      erb :guest
    end
  end

  get '/logout' do
    session[:user_email] = nil
    session[:access_token] = nil
    session[:authorized_scopes] = nil
    redirect('/')
  end

  get '/users' do
    content_type 'application/json'
    if session[:refresh_token]
      begin
        issuer = CF::UAA::TokenIssuer.new(UAA_URL, UAA_CLIENT, UAA_CLIENT_SECRET, UAA_OPTIONS)
        token_info = issuer.refresh_token_grant(session[:refresh_token])

        # Does the refresh_token ever change?
        session[:refresh_token] = token_info.info["refresh_token"]

        scim = CF::UAA::Scim.new(UAA_URL, token_info.auth_header, UAA_OPTIONS)
        scim.query(:user).to_json
      rescue CF::UAA::TargetError => e
        e.info.merge(authorized_scopes: session[:authorized_scopes]).to_json
      rescue CF::UAA::InvalidToken => e
        e.info.to_json
      end
    else
      {"error": "requires authentication"}.to_json
    end
  end

  get '/auth/cloudfoundry/callback' do
    content_type 'application/json'
    auth = request.env['omniauth.auth']
    session[:user_email] = auth.info.email
    # session[:access_token] = auth.credentials.token
    session[:refresh_token] = auth.credentials.refresh_token
    session[:authorized_scopes] = auth.credentials.authorized_scopes
    redirect('/')
  rescue "No Data"
  end

  get '/auth/failure' do
    content_type 'text/plain'
    request.env['omniauth.auth'].to_hash.inspect rescue "No Data"
  end
end

use Rack::Session::Cookie,
  key: 'rack.omniauth-login-and-uaa-api-calls',
  path: '/',
  expire_after: 2592000, # In seconds
  secret: ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

use OmniAuth::Builder do
  options = {
    auth_server_url: UAA_URL,
    token_server_url: UAA_URL,
    redirect_uri: 'http://localhost:9292/auth/cloudfoundry/callback'
  }
  if ENV['UAA_CA_CERT_FILE'] && File.exists?(ENV['UAA_CA_CERT_FILE']) && !File.read(ENV['UAA_CA_CERT_FILE']).strip.empty?
    options[:ssl_ca_file] = ENV['UAA_CA_CERT_FILE']
  else
    options[:skip_ssl_validation] = !!ENV['UAA_CA_CERT']
  end

  provider :cloudfoundry, UAA_CLIENT, UAA_CLIENT_SECRET, options
end

run App.new

