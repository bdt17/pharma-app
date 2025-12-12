require "test_helper"

class AiIntegrationServiceTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "Test Region")
    @site = Site.create!(name: "Test Site", region: @region)
    @truck = Truck.create!(
      name: "Test Truck",
      site: @site,
      status: "active",
      min_temp: 2,
      max_temp: 8
    )
    @route = Route.create!(
      name: "Test Route",
      origin: "Origin",
      destination: "Destination",
      truck: @truck,
      status: "in_progress",
      started_at: 2.hours.ago
    )

    # Create a provider in simulation mode (no api_key)
    @provider = AiProvider.create!(
      name: "Test Provider",
      provider_type: "custom",
      status: "active"
    )

    # Create test prompts
    @risk_prompt = AiPrompt.create!(
      name: "Risk Assessment",
      prompt_type: "risk_assessment",
      system_prompt: "You are a risk assessment AI.",
      user_prompt_template: "Assess risk for truck {{truck_name}} with temp range {{temp_range}}",
      active: true
    )

    @route_prompt = AiPrompt.create!(
      name: "Route Optimization",
      prompt_type: "route_optimization",
      system_prompt: "You are a route optimization AI.",
      user_prompt_template: "Optimize route {{route_name}} from {{origin}} to {{destination}}",
      active: true
    )

    @anomaly_prompt = AiPrompt.create!(
      name: "Anomaly Detection",
      prompt_type: "anomaly_detection",
      system_prompt: "You are an anomaly detection AI.",
      user_prompt_template: "Detect anomalies in telemetry for truck {{truck_name}}",
      active: true
    )

    @temp_prompt = AiPrompt.create!(
      name: "Temperature Prediction",
      prompt_type: "temperature_prediction",
      system_prompt: "You are a temperature prediction AI.",
      user_prompt_template: "Predict temperature for truck {{truck_name}} for {{hours_ahead}} hours",
      active: true
    )

    @compliance_prompt = AiPrompt.create!(
      name: "Compliance Review",
      prompt_type: "compliance_review",
      system_prompt: "You are a compliance review AI.",
      user_prompt_template: "Review compliance for route {{route_name}}",
      active: true
    )
  end

  test "assess_risk returns simulated response without API key" do
    result = AiIntegrationService.assess_risk(@truck)

    assert result[:success]
    assert result[:request].present?
    assert result[:response].present?
    assert result[:response][:risk_score].present?
    assert result[:response][:risk_level].present?
  end

  test "assess_risk creates insight" do
    result = AiIntegrationService.assess_risk(@truck)

    assert result[:success]
    insight = AiInsight.find_by(ai_request: result[:request])
    assert insight.present?
    assert_equal 'risk_prediction', insight.insight_type
    assert_equal @truck, insight.insightable
  end

  test "optimize_route returns recommendations" do
    result = AiIntegrationService.optimize_route(@route)

    assert result[:success]
    assert result[:response][:optimized].present?
    assert result[:response][:improvements].present?
  end

  test "detect_anomalies analyzes telemetry" do
    # Add some telemetry readings
    5.times do |i|
      @truck.telemetry_readings.create!(
        temperature_c: 4.0 + (i * 0.5),
        humidity: 50 + i,
        recorded_at: i.minutes.ago
      )
    end

    result = AiIntegrationService.detect_anomalies(@truck)

    assert result[:success]
    assert result[:response].key?(:anomalies)
  end

  test "predict_temperature returns forecast" do
    result = AiIntegrationService.predict_temperature(@truck, hours_ahead: 6)

    assert result[:success]
    assert result[:response][:predictions].present?
    assert result[:response][:excursion_risk].present?
  end

  test "review_compliance checks route" do
    result = AiIntegrationService.review_compliance(@route)

    assert result[:success]
    assert result[:response].key?(:compliant)
    assert result[:response][:score].present?
  end

  test "submit_feedback records feedback" do
    result = AiIntegrationService.assess_risk(@truck)
    insight = AiInsight.find_by(ai_request: result[:request])

    feedback = AiIntegrationService.submit_feedback(
      insight,
      feedback_type: 'accurate',
      rating: 5,
      comments: 'Very helpful prediction',
      user: 'test_user'
    )

    assert feedback.persisted?
    assert_equal 'accurate', feedback.feedback_type
    assert_equal 5, feedback.rating
  end

  test "usage_stats returns statistics" do
    # Create some requests
    3.times do
      AiIntegrationService.assess_risk(@truck)
    end

    stats = AiIntegrationService.usage_stats(period: 1.day)

    assert stats[:total_requests] >= 3
    assert stats[:by_type].present?
  end

  test "insights_for returns entity insights" do
    AiIntegrationService.assess_risk(@truck)
    AiIntegrationService.detect_anomalies(@truck)

    insights = AiIntegrationService.insights_for(@truck)

    assert insights.count >= 1
    insights.each do |insight|
      assert_equal @truck, insight.insightable
    end
  end

  test "active_alerts filters by severity" do
    result = AiIntegrationService.assess_risk(@truck)
    insight = AiInsight.find_by(ai_request: result[:request])
    insight.update!(severity: 'critical')

    critical_alerts = AiIntegrationService.active_alerts(severity: 'critical')

    assert critical_alerts.any? { |a| a.id == insight.id }
  end

  test "insight acknowledge updates status" do
    result = AiIntegrationService.assess_risk(@truck)
    insight = AiInsight.find_by(ai_request: result[:request])

    insight.acknowledge!('test_user')

    assert_equal 'acknowledged', insight.status
    assert insight.acknowledged_at.present?
    assert_equal 'test_user', insight.acknowledged_by
  end

  test "request tracks tokens and cost" do
    result = AiIntegrationService.assess_risk(@truck)

    request = result[:request]
    assert request.tokens_used.present?
    assert request.latency_ms.present?
    assert_equal 'completed', request.status
  end
end
