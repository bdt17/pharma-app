class MonitoringBroadcaster
  def self.broadcast(monitoring)
    new(monitoring).broadcast
  end

  def initialize(monitoring)
    @monitoring = monitoring
    @truck = monitoring.truck
  end

  def broadcast
    broadcast_to_truck_channel
    broadcast_to_dashboard_channel
  end

  private

  def broadcast_to_truck_channel
    return unless defined?(ActionCable)

    ActionCable.server.broadcast(
      "truck_#{@truck.id}",
      {
        truck_id: @truck.id,
        temperature: @monitoring.temperature,
        power_status: @monitoring.power_status,
        recorded_at: @monitoring.recorded_at&.iso8601
      }
    )
  end

  def broadcast_to_dashboard_channel
    return unless defined?(ActionCable)

    ActionCable.server.broadcast(
      "dashboard",
      {
        truck_id: @truck.id,
        truck_name: @truck.name,
        temperature: @monitoring.temperature,
        power_status: @monitoring.power_status,
        recorded_at: @monitoring.recorded_at&.iso8601,
        out_of_range: @truck.out_of_range?(@monitoring.temperature)
      }
    )
  end
end
