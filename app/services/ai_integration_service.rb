require 'net/http'
require 'json'

class AiIntegrationService
  class << self
    # Main entry point for AI-powered analysis
    def analyze(type:, subject:, context: {}, provider: nil)
      provider ||= default_provider
      prompt = AiPrompt.for_type(type)

      return { error: 'No active provider configured' } unless provider&.available?
      return { error: "No prompt template for type: #{type}" } unless prompt

      request = create_request(
        provider: provider,
        prompt: prompt,
        request_type: type,
        subject: subject,
        context: context
      )

      execute_request(request, provider, prompt, context)
    end

    # Risk assessment for trucks/routes
    def assess_risk(truck_or_route)
      context = build_risk_context(truck_or_route)
      result = analyze(type: 'risk_assessment', subject: truck_or_route, context: context)

      if result[:success]
        create_insight(
          request: result[:request],
          type: 'risk_prediction',
          subject: truck_or_route,
          data: result[:response]
        )
      end

      result
    end

    # Route optimization suggestions
    def optimize_route(route, constraints: {})
      context = build_route_context(route, constraints)
      result = analyze(type: 'route_optimization', subject: route, context: context)

      if result[:success]
        create_insight(
          request: result[:request],
          type: 'route_recommendation',
          subject: route,
          data: result[:response]
        )
      end

      result
    end

    # Anomaly detection in telemetry data
    def detect_anomalies(truck, readings: nil)
      readings ||= truck.telemetry_readings.recent.limit(100)
      context = build_telemetry_context(truck, readings)
      result = analyze(type: 'anomaly_detection', subject: truck, context: context)

      if result[:success] && result[:response][:anomalies].present?
        result[:response][:anomalies].each do |anomaly|
          create_insight(
            request: result[:request],
            type: 'anomaly_alert',
            subject: truck,
            data: anomaly
          )
        end
      end

      result
    end

    # Temperature prediction
    def predict_temperature(truck, hours_ahead: 4)
      context = build_temperature_context(truck, hours_ahead)
      result = analyze(type: 'temperature_prediction', subject: truck, context: context)

      if result[:success]
        create_insight(
          request: result[:request],
          type: 'temperature_forecast',
          subject: truck,
          data: result[:response]
        )
      end

      result
    end

    # Compliance review
    def review_compliance(route)
      context = build_compliance_context(route)
      result = analyze(type: 'compliance_review', subject: route, context: context)

      if result[:success] && !result[:response][:compliant]
        create_insight(
          request: result[:request],
          type: 'compliance_issue',
          subject: route,
          data: result[:response]
        )
      end

      result
    end

    # Incident analysis
    def analyze_incident(event)
      context = build_incident_context(event)
      result = analyze(type: 'incident_analysis', subject: event, context: context)

      if result[:success]
        create_insight(
          request: result[:request],
          type: 'incident_report',
          subject: event,
          data: result[:response]
        )
      end

      result
    end

    # Batch analysis for multiple entities
    def batch_analyze(entities, type:)
      results = []
      entities.each do |entity|
        result = analyze(type: type, subject: entity, context: build_context_for(entity, type))
        results << { entity: entity, result: result }
      end
      results
    end

    # Get insights for an entity
    def insights_for(entity, include_dismissed: false)
      scope = AiInsight.where(insightable: entity).recent
      scope = scope.where.not(status: 'dismissed') unless include_dismissed
      scope
    end

    # Get active alerts
    def active_alerts(severity: nil)
      scope = AiInsight.active.recent
      scope = scope.by_severity(severity) if severity
      scope
    end

    # Submit feedback for an insight
    def submit_feedback(insight, feedback_type:, rating: nil, comments: nil, user: nil)
      AiFeedback.create!(
        ai_insight: insight,
        feedback_type: feedback_type,
        rating: rating,
        comments: comments,
        submitted_by: user
      )
    end

    # Provider management
    def default_provider
      AiProvider.active.first
    end

    def available_providers
      AiProvider.active.to_a
    end

    # Statistics
    def usage_stats(period: 30.days)
      requests = AiRequest.where('created_at > ?', period.ago)
      {
        total_requests: requests.count,
        completed: requests.completed.count,
        failed: requests.failed.count,
        total_tokens: requests.sum(:tokens_used),
        total_cost: requests.sum(:cost),
        avg_latency_ms: requests.completed.average(:latency_ms)&.round(2),
        by_type: requests.group(:request_type).count,
        insights_generated: AiInsight.where('created_at > ?', period.ago).count
      }
    end

    private

    def create_request(provider:, prompt:, request_type:, subject:, context:)
      AiRequest.create!(
        ai_provider: provider,
        ai_prompt: prompt,
        request_type: request_type,
        requestable: subject,
        input_data: context.to_json,
        status: 'pending'
      )
    end

    def execute_request(request, provider, prompt, context)
      request.mark_processing!
      start_time = Time.current

      begin
        response = call_provider(provider, prompt, context)
        latency = ((Time.current - start_time) * 1000).to_i

        request.mark_completed!(
          response,
          tokens: response[:tokens_used],
          latency: latency
        )

        { success: true, request: request, response: response }
      rescue => e
        request.mark_failed!(e.message)
        { success: false, request: request, error: e.message }
      end
    end

    def call_provider(provider, prompt, context)
      # Use simulation mode if no API key configured
      return simulate_response(prompt, context) if provider.simulation_mode?

      case provider.provider_type
      when 'openai'
        call_openai(provider, prompt, context)
      when 'anthropic'
        call_anthropic(provider, prompt, context)
      when 'azure'
        call_azure(provider, prompt, context)
      when 'custom'
        call_custom(provider, prompt, context)
      else
        simulate_response(prompt, context)
      end
    end

    def call_openai(provider, prompt, context)
      # OpenAI API integration
      uri = URI(provider.endpoint_url || 'https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{provider.api_key_encrypted}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: provider.ai_model || 'gpt-4',
        messages: [
          { role: 'system', content: prompt.system_prompt },
          { role: 'user', content: prompt.render(context) }
        ],
        max_tokens: provider.max_tokens || 2000,
        temperature: provider.settings_hash['temperature'] || 0.7
      }.to_json

      response = http.request(request)
      data = JSON.parse(response.body)

      if data['error']
        raise "OpenAI API Error: #{data['error']['message']}"
      end

      {
        content: data.dig('choices', 0, 'message', 'content'),
        tokens_used: data.dig('usage', 'total_tokens'),
        model: data['model'],
        finish_reason: data.dig('choices', 0, 'finish_reason')
      }
    end

    def call_anthropic(provider, prompt, context)
      # Anthropic Claude API integration
      uri = URI(provider.endpoint_url || 'https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['x-api-key'] = provider.api_key_encrypted
      request['anthropic-version'] = '2023-06-01'
      request['Content-Type'] = 'application/json'
      request.body = {
        model: provider.ai_model || 'claude-3-sonnet-20240229',
        system: prompt.system_prompt,
        messages: [
          { role: 'user', content: prompt.render(context) }
        ],
        max_tokens: provider.max_tokens || 2000
      }.to_json

      response = http.request(request)
      data = JSON.parse(response.body)

      if data['error']
        raise "Anthropic API Error: #{data['error']['message']}"
      end

      {
        content: data.dig('content', 0, 'text'),
        tokens_used: (data.dig('usage', 'input_tokens') || 0) + (data.dig('usage', 'output_tokens') || 0),
        model: data['model'],
        stop_reason: data['stop_reason']
      }
    end

    def call_azure(provider, prompt, context)
      # Azure OpenAI integration
      uri = URI(provider.endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['api-key'] = provider.api_key_encrypted
      request['Content-Type'] = 'application/json'
      request.body = {
        messages: [
          { role: 'system', content: prompt.system_prompt },
          { role: 'user', content: prompt.render(context) }
        ],
        max_tokens: provider.max_tokens || 2000,
        temperature: provider.settings_hash['temperature'] || 0.7
      }.to_json

      response = http.request(request)
      data = JSON.parse(response.body)

      {
        content: data.dig('choices', 0, 'message', 'content'),
        tokens_used: data.dig('usage', 'total_tokens'),
        model: provider.ai_model
      }
    end

    def call_custom(provider, prompt, context)
      # Custom provider with webhook-style integration
      uri = URI(provider.endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{provider.api_key_encrypted}"
      request['Content-Type'] = 'application/json'
      request.body = {
        system_prompt: prompt.system_prompt,
        user_prompt: prompt.render(context),
        settings: provider.settings_hash
      }.to_json

      response = http.request(request)
      JSON.parse(response.body).deep_symbolize_keys
    end

    def simulate_response(prompt, context)
      # Simulation mode for testing without real API calls
      case prompt.prompt_type
      when 'risk_assessment'
        simulate_risk_response(context)
      when 'route_optimization'
        simulate_route_response(context)
      when 'anomaly_detection'
        simulate_anomaly_response(context)
      when 'temperature_prediction'
        simulate_temperature_response(context)
      when 'compliance_review'
        simulate_compliance_response(context)
      else
        { content: 'Simulated response', tokens_used: 100 }
      end
    end

    def simulate_risk_response(context)
      {
        risk_score: rand(0.1..0.9).round(2),
        risk_level: %w[low medium high].sample,
        factors: [
          { factor: 'temperature_stability', score: rand(0.5..1.0).round(2) },
          { factor: 'route_history', score: rand(0.5..1.0).round(2) },
          { factor: 'weather_conditions', score: rand(0.5..1.0).round(2) }
        ],
        recommendations: [
          'Consider adding additional monitoring points',
          'Check refrigeration unit calibration'
        ],
        tokens_used: 150
      }
    end

    def simulate_route_response(context)
      {
        optimized: true,
        improvements: [
          { type: 'time_saving', value: rand(10..30), unit: 'minutes' },
          { type: 'fuel_saving', value: rand(5..15), unit: 'percent' }
        ],
        suggested_stops: [
          { type: 'rest', location: 'Service Area A', reason: 'Driver break' },
          { type: 'monitoring', location: 'Checkpoint B', reason: 'Temperature verification' }
        ],
        tokens_used: 200
      }
    end

    def simulate_anomaly_response(context)
      has_anomaly = rand < 0.3
      {
        anomalies: has_anomaly ? [
          {
            type: %w[temperature_spike power_fluctuation gps_drift].sample,
            severity: %w[low medium high].sample,
            timestamp: Time.current.iso8601,
            description: 'Detected unusual pattern in sensor data'
          }
        ] : [],
        analysis_summary: 'Telemetry analysis complete',
        tokens_used: 175
      }
    end

    def simulate_temperature_response(context)
      {
        predictions: (1..4).map do |hour|
          {
            hours_ahead: hour,
            predicted_temp: rand(2.0..8.0).round(1),
            confidence: rand(0.7..0.95).round(2),
            range: { min: rand(1.0..3.0).round(1), max: rand(6.0..10.0).round(1) }
          }
        end,
        excursion_risk: rand(0.1..0.5).round(2),
        tokens_used: 180
      }
    end

    def simulate_compliance_response(context)
      {
        compliant: rand > 0.2,
        score: rand(70..100),
        issues: rand > 0.5 ? [
          { type: 'documentation', description: 'Missing signature on transfer record' }
        ] : [],
        recommendations: ['Ensure all handoffs are properly documented'],
        tokens_used: 160
      }
    end

    def create_insight(request:, type:, subject:, data:)
      AiInsight.create!(
        ai_request: request,
        insight_type: type,
        insightable: subject,
        title: generate_title(type, data),
        summary: generate_summary(type, data),
        details: data.to_json,
        confidence_score: data[:confidence] || data[:risk_score] || rand(0.7..0.95).round(2),
        severity: determine_severity(type, data)
      )
    end

    def generate_title(type, data)
      case type
      when 'risk_prediction'
        "Risk Level: #{data[:risk_level]&.titleize || 'Unknown'}"
      when 'route_recommendation'
        'Route Optimization Available'
      when 'anomaly_alert'
        "Anomaly Detected: #{data[:type]&.to_s&.titleize}"
      when 'temperature_forecast'
        'Temperature Prediction Update'
      when 'compliance_issue'
        'Compliance Review Required'
      else
        type.to_s.titleize
      end
    end

    def generate_summary(type, data)
      case type
      when 'risk_prediction'
        "Risk assessment completed with score #{data[:risk_score]}. #{data[:recommendations]&.first}"
      when 'route_recommendation'
        improvements = data[:improvements]&.map { |i| "#{i[:value]}#{i[:unit]} #{i[:type]}" }&.join(', ')
        "Route can be optimized: #{improvements}"
      when 'anomaly_alert'
        data[:description] || 'Unusual pattern detected in sensor data'
      when 'temperature_forecast'
        "Temperature predictions generated for the next #{data[:predictions]&.length || 4} hours"
      when 'compliance_issue'
        "Compliance score: #{data[:score]}. Issues found: #{data[:issues]&.length || 0}"
      else
        'Analysis completed'
      end
    end

    def determine_severity(type, data)
      case type
      when 'risk_prediction'
        case data[:risk_level]
        when 'high' then 'high'
        when 'medium' then 'medium'
        else 'low'
        end
      when 'anomaly_alert'
        data[:severity] || 'medium'
      when 'compliance_issue'
        data[:compliant] == false ? 'high' : 'low'
      else
        'low'
      end
    end

    def build_risk_context(entity)
      if entity.is_a?(Truck)
        {
          truck_id: entity.id,
          truck_name: entity.name,
          temp_range: "#{entity.min_temp}-#{entity.max_temp}°C",
          current_temp: entity.current_temperature,
          status: entity.status,
          recent_readings: entity.telemetry_readings.recent.limit(10).map do |r|
            { temp: r.temperature_c, time: r.recorded_at&.iso8601 }
          end
        }
      else # Route
        {
          route_id: entity.id,
          route_name: entity.name,
          origin: entity.origin,
          destination: entity.destination,
          status: entity.status,
          truck: entity.truck&.name,
          waypoints_count: entity.respond_to?(:route_waypoints) ? entity.route_waypoints.count : 0
        }
      end
    end

    def build_route_context(route, constraints)
      waypoints_data = if route.respond_to?(:route_waypoints)
                         route.route_waypoints.ordered.map do |wp|
                           { name: wp.name, lat: wp.latitude, lng: wp.longitude, type: wp.stop_type }
                         end
                       else
                         []
                       end
      {
        route_id: route.id,
        route_name: route.name,
        origin: route.origin,
        destination: route.destination,
        waypoints: waypoints_data,
        truck: route.truck&.name,
        constraints: constraints
      }
    end

    def build_telemetry_context(truck, readings)
      {
        truck_id: truck.id,
        truck_name: truck.name,
        temp_range: "#{truck.min_temp}-#{truck.max_temp}°C",
        readings: readings.map do |r|
          {
            temperature: r.temperature_c,
            humidity: r.humidity,
            latitude: r.latitude,
            longitude: r.longitude,
            battery_level: r.try(:battery_level),
            recorded_at: r.recorded_at&.iso8601
          }
        end
      }
    end

    def build_temperature_context(truck, hours_ahead)
      {
        truck_id: truck.id,
        truck_name: truck.name,
        temp_range: "#{truck.min_temp}-#{truck.max_temp}°C",
        current_temp: truck.current_temperature,
        recent_temps: truck.telemetry_readings.recent.limit(20).pluck(:temperature_c),
        hours_ahead: hours_ahead
      }
    end

    def build_compliance_context(route)
      {
        route_id: route.id,
        route_name: route.name,
        events: route.truck&.shipment_events&.where(route: route)&.map do |e|
          {
            type: e.event_type,
            timestamp: e.timestamp&.iso8601,
            verified: e.verified,
            signature: e.digital_signature.present?
          }
        end || [],
        truck: route.truck&.name,
        started_at: route.started_at&.iso8601,
        completed_at: route.completed_at&.iso8601
      }
    end

    def build_incident_context(event)
      {
        event_id: event.id,
        event_type: event.event_type,
        timestamp: event.timestamp&.iso8601,
        location: event.location,
        details: event.details_hash,
        truck: event.truck&.name,
        route: event.route&.name
      }
    end

    def build_context_for(entity, type)
      case type
      when 'risk_assessment'
        build_risk_context(entity)
      when 'anomaly_detection'
        build_telemetry_context(entity, entity.telemetry_readings.recent.limit(50))
      when 'temperature_prediction'
        build_temperature_context(entity, 4)
      when 'compliance_review'
        build_compliance_context(entity)
      else
        { entity_id: entity.id, entity_type: entity.class.name }
      end
    end
  end
end
