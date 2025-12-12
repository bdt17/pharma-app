class Api::V1::HealthController < ActionController::API
  # No authentication required for health checks

  def show
    render json: HealthCheckService.quick_check
  end

  def full
    render json: HealthCheckService.full_check
  end

  def ready
    result = HealthCheckService.readiness_check
    status = result[:ready] ? :ok : :service_unavailable
    render json: result, status: status
  end

  def live
    render json: HealthCheckService.liveness_check
  end

  def metrics
    render json: {
      timestamp: Time.current.iso8601,
      database: database_metrics,
      cache: cache_metrics,
      api: api_metrics,
      entities: entity_counts
    }
  end

  private

  def database_metrics
    {
      connection_pool: ActiveRecord::Base.connection_pool.stat,
      migrations_pending: ActiveRecord::Migration.check_all_pending! rescue true
    }
  rescue => e
    { error: e.message }
  end

  def cache_metrics
    {
      backend: Rails.cache.class.name
    }
  end

  def api_metrics
    {
      requests_today: CacheService.get_counter("api_requests:#{Date.current}"),
      rate_limit_hits: CacheService.get_counter("rate_limit_hits:#{Date.current}")
    }
  end

  def entity_counts
    {
      trucks: Truck.count,
      routes: Route.count,
      active_routes: Route.where(status: 'in_progress').count,
      telemetry_readings_today: TelemetryReading.where('recorded_at > ?', Date.current.beginning_of_day).count,
      ai_requests_today: AiRequest.where('created_at > ?', Date.current.beginning_of_day).count
    }
  rescue => e
    { error: e.message }
  end
end
