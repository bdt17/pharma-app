class Api::V1::HealthController < ActionController::API
  def show
    render json: {
      status: "ok",
      time: Time.current
    }
  end

  def database_metrics
    pending =
      begin
        ActiveRecord::Migration.check_all_pending!
        false
      rescue
        true
      end

    render json: {
      connection_pool: ActiveRecord::Base.connection_pool.stat,
      migrations_pending: pending
    }
  rescue => e
    render json: { error: e.class.name, message: e.message }, status: :internal_server_error
  end
end
