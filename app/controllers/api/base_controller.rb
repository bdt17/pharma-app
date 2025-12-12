class Api::BaseController < ApplicationController
  protect_from_forgery with: :null_session

  TOKEN = ENV.fetch("PHARMA_API_TOKEN", "dev-secret-token")

  before_action :authenticate_api_token
  before_action :set_default_format

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def authenticate_api_token
    authenticate_or_request_with_http_token do |token, _|
      ActiveSupport::SecurityUtils.secure_compare(token, TOKEN)
    end
  end

  def set_default_format
    request.format = :json unless params[:format]
  end

  def not_found(exception)
    render json: { error: "Resource not found", details: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: "Validation failed", details: exception.record&.errors&.full_messages }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: "Bad request", details: exception.message }, status: :bad_request
  end
end
