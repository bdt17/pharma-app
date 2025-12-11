class Api::BaseController < ApplicationController
  protect_from_forgery with: :null_session

  TOKEN = ENV.fetch("PHARMA_API_TOKEN", "dev-secret-token")

  before_action :authenticate_api_token

  private

  def authenticate_api_token
    authenticate_or_request_with_http_token do |token, _|
      ActiveSupport::SecurityUtils.secure_compare(token, TOKEN)
    end
  end
end
