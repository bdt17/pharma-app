class Api::V1::BatchController < Api::BaseController
  # Rate limit batch operations more strictly
  before_action :check_batch_rate_limit

  # Batch telemetry ingestion
  def telemetry
    truck_id = params[:truck_id]
    readings = params[:readings]

    unless readings.is_a?(Array) && readings.size <= 1000
      return render json: { error: 'Readings must be an array with max 1000 items' }, status: :bad_request
    end

    result = BatchProcessor.process_telemetry_batch(truck_id, readings)

    if result[:errors].empty?
      render json: { processed: result[:processed], status: 'success' }, status: :created
    else
      render json: {
        processed: result[:processed],
        errors: result[:errors],
        status: 'partial'
      }, status: :multi_status
    end
  end

  # Batch monitoring data
  def monitoring
    truck_id = params[:truck_id]
    readings = params[:readings]

    unless readings.is_a?(Array) && readings.size <= 1000
      return render json: { error: 'Readings must be an array with max 1000 items' }, status: :bad_request
    end

    result = BatchProcessor.process_monitoring_batch(truck_id, readings)

    render json: { processed: result[:processed], errors: result[:errors] },
           status: result[:errors].empty? ? :created : :multi_status
  end

  # Batch shipment events
  def events
    truck_id = params[:truck_id]
    events = params[:events]

    unless events.is_a?(Array) && events.size <= 100
      return render json: { error: 'Events must be an array with max 100 items' }, status: :bad_request
    end

    result = BatchProcessor.process_events_batch(truck_id, events)

    render json: { processed: result[:processed], errors: result[:errors] },
           status: result[:errors].empty? ? :created : :multi_status
  end

  # Batch warehouse readings
  def warehouse_readings
    warehouse_id = params[:warehouse_id]
    readings = params[:readings]

    unless readings.is_a?(Array) && readings.size <= 1000
      return render json: { error: 'Readings must be an array with max 1000 items' }, status: :bad_request
    end

    result = BatchProcessor.process_warehouse_readings_batch(warehouse_id, readings)

    render json: { processed: result[:processed], errors: result[:errors] },
           status: result[:errors].empty? ? :created : :multi_status
  end

  # Batch AI analysis
  def ai_analysis
    entity_type = params[:entity_type]
    entity_ids = params[:entity_ids]
    analysis_type = params[:analysis_type]

    unless %w[truck route].include?(entity_type.to_s.downcase)
      return render json: { error: 'Invalid entity type' }, status: :bad_request
    end

    unless entity_ids.is_a?(Array) && entity_ids.size <= 50
      return render json: { error: 'Entity IDs must be an array with max 50 items' }, status: :bad_request
    end

    result = BatchProcessor.batch_ai_analysis(entity_type, entity_ids, analysis_type)

    render json: {
      processed: result[:processed],
      results: result[:results],
      errors: result[:errors]
    }, status: result[:errors].empty? ? :ok : :multi_status
  end

  # Export data
  def export
    case params[:type]
    when 'telemetry'
      export_telemetry
    when 'monitoring'
      export_monitoring
    when 'events'
      export_events
    else
      render json: { error: 'Unknown export type' }, status: :bad_request
    end
  end

  private

  def check_batch_rate_limit
    RateLimiter.check_ip!(request.remote_ip, category: :api_telemetry)
  rescue RateLimiter::RateLimitExceeded => e
    render json: {
      error: 'Rate limit exceeded',
      retry_after: e.retry_after
    }, status: :too_many_requests
  end

  def export_telemetry
    truck = Truck.find(params[:truck_id])
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 7.days.ago.to_date
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current

    format = params[:format]&.to_sym || :json

    data = BatchProcessor.export_telemetry(
      truck.id,
      start_date: start_date.beginning_of_day,
      end_date: end_date.end_of_day,
      format: format
    )

    case format
    when :csv
      send_data data,
                filename: "telemetry_#{truck.id}_#{start_date}_#{end_date}.csv",
                type: 'text/csv'
    else
      render json: { truck_id: truck.id, start_date: start_date, end_date: end_date, readings: data }
    end
  end

  def export_monitoring
    truck = Truck.find(params[:truck_id])
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 7.days.ago.to_date
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current

    readings = truck.monitorings
                    .where(recorded_at: start_date.beginning_of_day..end_date.end_of_day)
                    .order(recorded_at: :asc)
                    .as_json(only: %w[recorded_at temperature power_status])

    render json: { truck_id: truck.id, start_date: start_date, end_date: end_date, readings: readings }
  end

  def export_events
    truck = Truck.find(params[:truck_id])
    route_id = params[:route_id]

    events = truck.shipment_events
    events = events.where(route_id: route_id) if route_id.present?
    events = events.order(recorded_at: :asc)
                   .as_json(only: %w[event_type description recorded_at recorded_by latitude longitude temperature_c])

    render json: { truck_id: truck.id, route_id: route_id, events: events }
  end
end
