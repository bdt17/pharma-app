class ApplicationController < ActionController::Base
  before_action :set_security_headers

  rescue_from StandardError, with: :handle_error if Rails.env.production?

  private

  def set_security_headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  end

  def handle_error(exception)
    Rails.logger.error("Unhandled exception: #{exception.class} - #{exception.message}")
    Rails.logger.error(exception.backtrace.first(10).join("\n"))

    respond_to do |format|
      format.html { render file: Rails.public_path.join("500.html"), status: :internal_server_error, layout: false }
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end
end
