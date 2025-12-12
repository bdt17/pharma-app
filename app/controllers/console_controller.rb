class ConsoleController < ApplicationController
  def index
    @trucks = Truck.includes(:site, :monitorings, :telemetry_readings).order(:name)
    @recent_alerts = recent_alerts
    @recent_monitorings = Monitoring.includes(truck: :site)
                                     .order(recorded_at: :desc)
                                     .limit(50)
    @recent_telemetry = TelemetryReading.includes(truck: :site)
                                        .order(recorded_at: :desc)
                                        .limit(20)
    @recent_events = ShipmentEvent.includes(:truck)
                                  .order(recorded_at: :desc)
                                  .limit(10)
    @active_routes = Route.where(status: 'in_progress').includes(:truck, :waypoints)
    @early_warnings = PredictiveRiskEngine.early_warnings(@active_routes)
  end

  def alerts
    render json: recent_alerts
  end

  def live_data
    active_routes = Route.where(status: 'in_progress').includes(:truck, :waypoints)
    render json: {
      trucks: trucks_status,
      alerts: recent_alerts,
      stats: live_stats,
      active_routes: active_routes_status,
      early_warnings: PredictiveRiskEngine.early_warnings(active_routes)
    }
  end

  private

  def recent_alerts
    alerts = []
    Truck.includes(:site, :monitorings).find_each do |truck|
      last_monitoring = truck.monitorings.order(recorded_at: :desc).first
      next unless last_monitoring

      if truck.out_of_range?(last_monitoring.temperature)
        alerts << {
          id: "#{truck.id}-#{last_monitoring.id}",
          truck_id: truck.id,
          truck_name: truck.name,
          site_name: truck.site&.name || "Unassigned",
          temperature: last_monitoring.temperature,
          min_temp: truck.min_temp,
          max_temp: truck.max_temp,
          power_status: last_monitoring.power_status,
          recorded_at: last_monitoring.recorded_at,
          risk_level: truck.risk_level,
          risk_score: truck.risk_score,
          type: determine_alert_type(truck, last_monitoring)
        }
      end

      if last_monitoring.power_status == 'off'
        alerts << {
          id: "power-#{truck.id}-#{last_monitoring.id}",
          truck_id: truck.id,
          truck_name: truck.name,
          site_name: truck.site&.name || "Unassigned",
          temperature: last_monitoring.temperature,
          power_status: last_monitoring.power_status,
          recorded_at: last_monitoring.recorded_at,
          type: 'power_failure'
        }
      end
    end
    alerts.sort_by { |a| a[:recorded_at] }.reverse.first(20)
  end

  def trucks_status
    Truck.includes(:site, :monitorings, :telemetry_readings).map do |truck|
      last_monitoring = truck.monitorings.order(recorded_at: :desc).first
      last_telemetry = truck.telemetry_readings.order(recorded_at: :desc).first
      temp = last_telemetry&.temperature_c || last_monitoring&.temperature
      {
        id: truck.id,
        name: truck.name,
        site_name: truck.site&.name,
        status: truck.status,
        risk_level: truck.risk_level,
        risk_score: truck.risk_score&.round,
        temperature: temp,
        power_status: last_monitoring&.power_status,
        latitude: last_telemetry&.latitude,
        longitude: last_telemetry&.longitude,
        speed_kph: last_telemetry&.speed_kph,
        last_reading: last_telemetry&.recorded_at || last_monitoring&.recorded_at,
        out_of_range: temp ? truck.out_of_range?(temp) : false
      }
    end
  end

  def active_routes_status
    Route.where(status: 'in_progress').includes(:truck, :waypoints).map do |route|
      {
        id: route.id,
        name: route.name,
        truck_name: route.truck&.name,
        progress: route.progress_percentage,
        completed_stops: route.completed_stops,
        total_stops: route.total_stops,
        started_at: route.started_at,
        risk_score: route.risk_score,
        risk_level: route.risk_level
      }
    end
  end

  def live_stats
    {
      total_trucks: Truck.count,
      trucks_in_range: Truck.count - out_of_range_count,
      trucks_out_of_range: out_of_range_count,
      high_risk_trucks: Truck.where(risk_level: ['high', 'critical']).count,
      active_alerts: recent_alerts.count
    }
  end

  def out_of_range_count
    count = 0
    Truck.includes(:monitorings).find_each do |truck|
      last = truck.monitorings.order(recorded_at: :desc).first
      count += 1 if last && truck.out_of_range?(last.temperature)
    end
    count
  end

  def determine_alert_type(truck, monitoring)
    return 'critical' if truck.risk_level == 'critical'
    return 'high' if truck.risk_level == 'high'

    if truck.min_temp && monitoring.temperature < truck.min_temp
      'too_cold'
    elsif truck.max_temp && monitoring.temperature > truck.max_temp
      'too_hot'
    else
      'warning'
    end
  end
end
