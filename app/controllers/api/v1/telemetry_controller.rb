class Api::V1::TelemetryController < Api::BaseController
  MAX_LIMIT = 500
  DEFAULT_LIMIT = 100

  before_action :set_truck
  before_action :validate_telemetry_params, only: [:create]

  def create
    reading = @truck.telemetry_readings.new(sanitized_telemetry_params)
    reading.recorded_at ||= Time.current

    if reading.save
      render json: {
        id: reading.id,
        truck_id: reading.truck_id,
        recorded_at: reading.recorded_at,
        latitude: reading.latitude,
        longitude: reading.longitude,
        temperature_c: reading.temperature_c,
        humidity: reading.humidity,
        speed_kph: reading.speed_kph,
        out_of_range: reading.out_of_range?
      }, status: :created
    else
      render json: { errors: reading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    limit = [[params[:limit].to_i, DEFAULT_LIMIT].max, MAX_LIMIT].min
    readings = @truck.telemetry_readings.recent.limit(limit)

    render json: readings.map { |r| serialize_reading(r) }
  end

  def latest
    reading = @truck.latest_telemetry

    if reading
      render json: serialize_reading(reading)
    else
      render json: { error: "No telemetry data" }, status: :not_found
    end
  end

  private

  def set_truck
    @truck = Truck.find(params[:truck_id])
  end

  def telemetry_params
    params.require(:telemetry).permit(
      :latitude, :longitude, :recorded_at,
      :temperature_c, :humidity, :speed_kph,
      raw_payload: {}
    )
  end

  def validate_telemetry_params
    tp = telemetry_params

    if tp[:latitude].present? && (tp[:latitude].to_f < -90 || tp[:latitude].to_f > 90)
      render json: { error: "Invalid latitude (must be -90 to 90)" }, status: :bad_request
      return
    end

    if tp[:longitude].present? && (tp[:longitude].to_f < -180 || tp[:longitude].to_f > 180)
      render json: { error: "Invalid longitude (must be -180 to 180)" }, status: :bad_request
      return
    end

    if tp[:temperature_c].present? && (tp[:temperature_c].to_f < -100 || tp[:temperature_c].to_f > 100)
      render json: { error: "Invalid temperature (must be -100 to 100)" }, status: :bad_request
      return
    end

    if tp[:humidity].present? && (tp[:humidity].to_f < 0 || tp[:humidity].to_f > 100)
      render json: { error: "Invalid humidity (must be 0 to 100)" }, status: :bad_request
      return
    end

    if tp[:speed_kph].present? && (tp[:speed_kph].to_f < 0 || tp[:speed_kph].to_f > 500)
      render json: { error: "Invalid speed (must be 0 to 500)" }, status: :bad_request
      return
    end

    if tp[:recorded_at].present?
      begin
        time = Time.parse(tp[:recorded_at].to_s)
        if time > 1.hour.from_now
          render json: { error: "recorded_at cannot be in the future" }, status: :bad_request
          return
        end
      rescue ArgumentError
        render json: { error: "Invalid recorded_at format" }, status: :bad_request
        return
      end
    end
  end

  def sanitized_telemetry_params
    tp = telemetry_params.to_h
    tp[:latitude] = tp[:latitude].to_f.round(6) if tp[:latitude].present?
    tp[:longitude] = tp[:longitude].to_f.round(6) if tp[:longitude].present?
    tp[:temperature_c] = tp[:temperature_c].to_f.round(2) if tp[:temperature_c].present?
    tp[:humidity] = tp[:humidity].to_f.round(1) if tp[:humidity].present?
    tp[:speed_kph] = tp[:speed_kph].to_f.round(1) if tp[:speed_kph].present?
    tp
  end

  def serialize_reading(reading)
    {
      id: reading.id,
      truck_id: reading.truck_id,
      recorded_at: reading.recorded_at,
      latitude: reading.latitude,
      longitude: reading.longitude,
      temperature_c: reading.temperature_c,
      humidity: reading.humidity,
      speed_kph: reading.speed_kph,
      out_of_range: reading.out_of_range?,
      raw_payload: reading.raw_payload
    }
  end
end
