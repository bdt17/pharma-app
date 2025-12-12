class RiskScorer
  RISK_LEVELS = {
    low: { min: 0, max: 30 },
    medium: { min: 31, max: 60 },
    high: { min: 61, max: 80 },
    critical: { min: 81, max: 100 }
  }.freeze

  LOOKBACK_HOURS = 24

  def self.for_truck(truck)
    new(truck).calculate
  end

  def self.recalculate_all
    Truck.find_each do |truck|
      for_truck(truck)
    end
  end

  def initialize(truck)
    @truck = truck
  end

  def calculate
    score = compute_score
    level = determine_level(score)

    @truck.update!(risk_score: score, risk_level: level)

    { score: score, level: level }
  end

  private

  def compute_score
    recent_monitorings = @truck.monitorings
                               .where("recorded_at > ?", LOOKBACK_HOURS.hours.ago)
                               .order(:recorded_at)

    return 0 if recent_monitorings.empty?

    scores = []

    # Factor 1: Excursion count (out of range readings)
    scores << excursion_score(recent_monitorings)

    # Factor 2: Excursion severity (how far out of range)
    scores << severity_score(recent_monitorings)

    # Factor 3: Temperature variance (instability)
    scores << variance_score(recent_monitorings)

    # Factor 4: Trend analysis (is temperature getting worse?)
    scores << trend_score(recent_monitorings)

    # Factor 5: Data freshness (recent data is good)
    scores << freshness_score(recent_monitorings)

    # Weighted average
    weighted_score = (
      scores[0] * 0.30 +  # Excursion count
      scores[1] * 0.25 +  # Severity
      scores[2] * 0.15 +  # Variance
      scores[3] * 0.20 +  # Trend
      scores[4] * 0.10    # Freshness
    )

    [weighted_score.round, 100].min
  end

  def excursion_score(monitorings)
    return 0 if monitorings.empty?

    excursion_count = monitorings.count do |m|
      @truck.out_of_range?(m.temperature)
    end

    ratio = excursion_count.to_f / monitorings.count
    (ratio * 100).round
  end

  def severity_score(monitorings)
    return 0 unless @truck.min_temp.present? || @truck.max_temp.present?

    max_deviation = 0

    monitorings.each do |m|
      next unless m.temperature.present?

      if @truck.min_temp.present? && m.temperature < @truck.min_temp
        deviation = @truck.min_temp - m.temperature
        max_deviation = [max_deviation, deviation].max
      end

      if @truck.max_temp.present? && m.temperature > @truck.max_temp
        deviation = m.temperature - @truck.max_temp
        max_deviation = [max_deviation, deviation].max
      end
    end

    # Score based on deviation: 5°C deviation = 50 points, 10°C = 100 points
    [(max_deviation * 10).round, 100].min
  end

  def variance_score(monitorings)
    temps = monitorings.map(&:temperature).compact
    return 0 if temps.size < 2

    mean = temps.sum / temps.size
    variance = temps.map { |t| (t - mean) ** 2 }.sum / temps.size
    std_dev = Math.sqrt(variance)

    # Score based on standard deviation: 2°C std dev = 40 points, 5°C = 100 points
    [(std_dev * 20).round, 100].min
  end

  def trend_score(monitorings)
    temps = monitorings.last(10).map(&:temperature).compact
    return 0 if temps.size < 3

    # Simple linear trend: positive means warming, negative means cooling
    first_half_avg = temps.first(temps.size / 2).sum / (temps.size / 2)
    second_half_avg = temps.last(temps.size / 2).sum / (temps.size / 2)
    trend = second_half_avg - first_half_avg

    # Score based on how much temperature is moving away from safe range
    return 0 unless @truck.min_temp.present? && @truck.max_temp.present?

    mid_point = (@truck.min_temp + @truck.max_temp) / 2
    current_avg = temps.last(3).sum / 3

    # If moving toward limits, increase score
    if current_avg > mid_point && trend > 0
      [(trend.abs * 20).round, 100].min
    elsif current_avg < mid_point && trend < 0
      [(trend.abs * 20).round, 100].min
    else
      0
    end
  end

  def freshness_score(monitorings)
    last_reading = monitorings.last
    return 100 unless last_reading&.recorded_at

    hours_ago = (Time.current - last_reading.recorded_at) / 1.hour

    if hours_ago < 1
      0
    elsif hours_ago < 4
      25
    elsif hours_ago < 12
      50
    elsif hours_ago < 24
      75
    else
      100
    end
  end

  def determine_level(score)
    RISK_LEVELS.each do |level, range|
      return level.to_s if score >= range[:min] && score <= range[:max]
    end
    "unknown"
  end
end
