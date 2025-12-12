class TelemetryBroadcaster
  def self.broadcast(reading)
    new(reading).broadcast
  end

  def initialize(reading)
    @reading = reading
    @truck = reading.truck
  end

  def broadcast
    broadcast_to_console
    broadcast_to_truck_channel
    send_alert_if_needed
  end

  private

  def broadcast_to_console
    return unless defined?(ActionCable)

    ActionCable.server.broadcast("console_updates", {
      type: "telemetry",
      truck_id: @truck.id,
      truck_name: @truck.name,
      site_name: @truck.site&.name,
      latitude: @reading.latitude,
      longitude: @reading.longitude,
      temperature_c: @reading.temperature_c,
      humidity: @reading.humidity,
      speed_kph: @reading.speed_kph,
      recorded_at: @reading.recorded_at&.iso8601,
      out_of_range: @reading.out_of_range?,
      risk_level: @truck.risk_level
    })
  end

  def broadcast_to_truck_channel
    return unless defined?(ActionCable)

    ActionCable.server.broadcast("truck_#{@truck.id}", {
      type: "telemetry",
      truck_id: @truck.id,
      latitude: @reading.latitude,
      longitude: @reading.longitude,
      temperature_c: @reading.temperature_c,
      humidity: @reading.humidity,
      speed_kph: @reading.speed_kph,
      recorded_at: @reading.recorded_at&.iso8601,
      out_of_range: @reading.out_of_range?
    })
  end

  def send_alert_if_needed
    return unless @reading.out_of_range?

    broadcast_alert
    queue_alert_email
  end

  def broadcast_alert
    return unless defined?(ActionCable)

    ActionCable.server.broadcast("console_updates", {
      type: "alert",
      alert_type: alert_type,
      truck_id: @truck.id,
      truck_name: @truck.name,
      site_name: @truck.site&.name,
      temperature_c: @reading.temperature_c,
      min_temp: @truck.min_temp,
      max_temp: @truck.max_temp,
      recorded_at: @reading.recorded_at&.iso8601,
      risk_level: @truck.risk_level
    })
  end

  def queue_alert_email
    return unless ENV["ALERT_EMAIL"].present?

    AlertMailer.telemetry_excursion(
      ENV["ALERT_EMAIL"],
      @truck,
      @reading
    ).deliver_later
  rescue StandardError => e
    Rails.logger.error("Failed to queue alert email: #{e.message}")
  end

  def alert_type
    return "too_cold" if @truck.min_temp && @reading.temperature_c < @truck.min_temp
    return "too_hot" if @truck.max_temp && @reading.temperature_c > @truck.max_temp
    "out_of_range"
  end
end
