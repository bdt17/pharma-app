class PredictiveRiskEngine
  RISK_BANDS = {
    low: { min: 0, max: 30, label: 'Low' },
    medium: { min: 31, max: 60, label: 'Medium' },
    high: { min: 61, max: 100, label: 'High' }
  }.freeze

  EXCURSION_THRESHOLD = 0.4
  EARLY_WARNING_THRESHOLD = 0.6

  def self.forecast(route)
    new(route).forecast
  end

  def self.early_warnings(routes = nil)
    routes ||= Route.where(status: 'in_progress').includes(:truck, :waypoints)
    routes.map do |route|
      forecast = new(route).forecast
      next unless forecast[:excursion_probability] >= EARLY_WARNING_THRESHOLD

      {
        route_id: route.id,
        route_name: route.name,
        truck_name: route.truck&.name,
        forecast: forecast,
        warning_level: forecast[:excursion_probability] >= 0.8 ? 'critical' : 'elevated'
      }
    end.compact
  end

  def initialize(route)
    @route = route
    @truck = route.truck
  end

  def forecast
    excursion_prob = calculate_excursion_probability
    ontime_prob = calculate_ontime_probability
    risk_band = determine_risk_band(excursion_prob, ontime_prob)

    {
      route_id: @route.id,
      excursion_probability: excursion_prob.round(2),
      ontime_probability: ontime_prob.round(2),
      risk_band: risk_band,
      risk_band_label: RISK_BANDS[risk_band][:label],
      factors: compute_factors,
      early_warning: excursion_prob >= EARLY_WARNING_THRESHOLD,
      recommendations: generate_recommendations(excursion_prob, ontime_prob),
      forecast_generated_at: Time.current
    }
  end

  private

  def calculate_excursion_probability
    factors = compute_factors

    base_probability = 0.05

    base_probability += factors[:current_temp_deviation] * 0.3
    base_probability += factors[:temp_variance_factor] * 0.2
    base_probability += factors[:truck_risk_factor] * 0.25
    base_probability += factors[:route_progress_factor] * 0.1
    base_probability += factors[:time_in_transit_factor] * 0.15

    base_probability.clamp(0.0, 1.0)
  end

  def calculate_ontime_probability
    return 0.5 unless @route.in_progress?

    factors = compute_factors

    base_probability = 0.9

    base_probability -= factors[:delay_factor] * 0.4
    base_probability -= factors[:remaining_stops_factor] * 0.2
    base_probability -= factors[:route_risk_factor] * 0.1

    base_probability.clamp(0.0, 1.0)
  end

  def compute_factors
    @factors ||= {
      current_temp_deviation: current_temp_deviation_factor,
      temp_variance_factor: temp_variance_factor,
      truck_risk_factor: truck_risk_factor,
      route_progress_factor: route_progress_factor,
      time_in_transit_factor: time_in_transit_factor,
      delay_factor: delay_factor,
      remaining_stops_factor: remaining_stops_factor,
      route_risk_factor: route_risk_factor
    }
  end

  def current_temp_deviation_factor
    return 0.0 unless @truck

    latest = @truck.latest_telemetry || @truck.monitorings.order(recorded_at: :desc).first
    return 0.3 unless latest

    temp = latest.respond_to?(:temperature_c) ? latest.temperature_c : latest.temperature
    return 0.0 unless temp

    min_temp = @truck.min_temp || 2
    max_temp = @truck.max_temp || 8
    mid_point = (min_temp + max_temp) / 2.0
    range = (max_temp - min_temp) / 2.0

    deviation = (temp - mid_point).abs / range
    deviation.clamp(0.0, 1.0)
  end

  def temp_variance_factor
    return 0.0 unless @truck

    readings = recent_temperatures
    return 0.0 if readings.size < 3

    mean = readings.sum / readings.size
    variance = readings.map { |t| (t - mean) ** 2 }.sum / readings.size
    std_dev = Math.sqrt(variance)

    (std_dev / 3.0).clamp(0.0, 1.0)
  end

  def truck_risk_factor
    return 0.3 unless @truck&.risk_score

    (@truck.risk_score / 100.0).clamp(0.0, 1.0)
  end

  def route_progress_factor
    return 0.5 unless @route.in_progress?

    progress = @route.progress_percentage / 100.0
    remaining = 1.0 - progress

    remaining * 0.5
  end

  def time_in_transit_factor
    return 0.0 unless @route.started_at

    hours_elapsed = (Time.current - @route.started_at) / 1.hour
    max_hours = @route.max_transit_hours || 24

    ratio = hours_elapsed / max_hours
    (ratio * 0.8).clamp(0.0, 1.0)
  end

  def delay_factor
    return 0.0 unless @route.started_at && @route.estimated_duration

    expected_progress = calculate_expected_progress
    actual_progress = @route.progress_percentage / 100.0

    delay = expected_progress - actual_progress
    delay.clamp(0.0, 1.0)
  end

  def remaining_stops_factor
    remaining = @route.total_stops - @route.completed_stops
    total = @route.total_stops

    return 0.0 if total.zero?

    (remaining.to_f / total).clamp(0.0, 1.0)
  end

  def route_risk_factor
    risk = @route.risk_score rescue 0
    (risk / 100.0).clamp(0.0, 1.0)
  end

  def calculate_expected_progress
    return 0.0 unless @route.started_at && @route.estimated_duration

    elapsed_minutes = (Time.current - @route.started_at) / 60
    (elapsed_minutes / @route.estimated_duration).clamp(0.0, 1.0)
  end

  def recent_temperatures
    return [] unless @truck

    telemetry_temps = @truck.telemetry_readings
                           .where("recorded_at > ?", 6.hours.ago)
                           .pluck(:temperature_c)
                           .compact

    return telemetry_temps if telemetry_temps.any?

    @truck.monitorings
         .where("recorded_at > ?", 6.hours.ago)
         .pluck(:temperature)
         .compact
  end

  def determine_risk_band(excursion_prob, ontime_prob)
    combined_risk = (excursion_prob * 0.7 + (1 - ontime_prob) * 0.3) * 100

    RISK_BANDS.each do |band, config|
      return band if combined_risk >= config[:min] && combined_risk <= config[:max]
    end

    :medium
  end

  def generate_recommendations(excursion_prob, ontime_prob)
    recommendations = []

    if excursion_prob >= 0.8
      recommendations << {
        priority: 1,
        type: 'excursion_imminent',
        action: 'IMMEDIATE_ACTION',
        message: 'High probability of temperature excursion. Consider re-icing or rerouting to nearest cold storage.'
      }
    elsif excursion_prob >= 0.6
      recommendations << {
        priority: 2,
        type: 'excursion_risk',
        action: 'MONITOR_CLOSELY',
        message: 'Elevated excursion risk. Increase monitoring frequency and prepare contingency.'
      }
    elsif excursion_prob >= 0.4
      recommendations << {
        priority: 3,
        type: 'excursion_watch',
        action: 'WATCH',
        message: 'Moderate excursion risk. Continue monitoring temperature trends.'
      }
    end

    if ontime_prob < 0.5
      recommendations << {
        priority: 2,
        type: 'delay_risk',
        action: 'EXPEDITE',
        message: 'Low on-time probability. Consider expediting or notifying recipients of delay.'
      }
    elsif ontime_prob < 0.7
      recommendations << {
        priority: 3,
        type: 'delay_watch',
        action: 'MONITOR',
        message: 'On-time delivery at risk. Monitor progress closely.'
      }
    end

    factors = compute_factors
    if factors[:temp_variance_factor] > 0.5
      recommendations << {
        priority: 2,
        type: 'temp_instability',
        action: 'CHECK_EQUIPMENT',
        message: 'High temperature variance detected. Check refrigeration unit operation.'
      }
    end

    recommendations.sort_by { |r| r[:priority] }
  end
end
