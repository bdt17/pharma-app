class Api::V1::AiController < Api::BaseController
  # Providers management
  def providers
    providers = AiProvider.order(created_at: :desc)
    providers = providers.active if params[:active] == 'true'
    providers = providers.by_type(params[:type]) if params[:type].present?

    render json: providers.map { |p| serialize_provider(p) }
  end

  def create_provider
    provider = AiProvider.new(provider_params)

    if provider.save
      render json: serialize_provider(provider), status: :created
    else
      render json: { errors: provider.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_provider
    provider = AiProvider.find(params[:id])

    if provider.update(provider_params)
      render json: serialize_provider(provider)
    else
      render json: { errors: provider.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Prompts management
  def prompts
    prompts = AiPrompt.order(created_at: :desc)
    prompts = prompts.active if params[:active] == 'true'
    prompts = prompts.by_type(params[:type]) if params[:type].present?

    render json: prompts.map { |p| serialize_prompt(p) }
  end

  def create_prompt
    prompt = AiPrompt.new(prompt_params)

    if prompt.save
      render json: serialize_prompt(prompt), status: :created
    else
      render json: { errors: prompt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_prompt
    prompt = AiPrompt.find(params[:id])

    if prompt.update(prompt_params)
      render json: serialize_prompt(prompt)
    else
      render json: { errors: prompt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Analysis endpoints
  def analyze
    type = params[:type]
    entity = find_entity

    unless entity
      return render json: { error: 'Entity not found' }, status: :not_found
    end

    result = AiIntegrationService.analyze(
      type: type,
      subject: entity,
      context: params[:context]&.to_unsafe_h || {}
    )

    if result[:success]
      render json: {
        request_id: result[:request].id,
        response: result[:response],
        insights: result[:request].ai_insights.map { |i| serialize_insight(i) }
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def assess_risk
    entity = find_entity
    unless entity
      return render json: { error: 'Entity not found' }, status: :not_found
    end

    result = AiIntegrationService.assess_risk(entity)
    render_analysis_result(result)
  end

  def optimize_route
    route = Route.find(params[:route_id])
    constraints = params[:constraints]&.to_unsafe_h || {}

    result = AiIntegrationService.optimize_route(route, constraints: constraints)
    render_analysis_result(result)
  end

  def detect_anomalies
    truck = Truck.find(params[:truck_id])

    result = AiIntegrationService.detect_anomalies(truck)
    render_analysis_result(result)
  end

  def predict_temperature
    truck = Truck.find(params[:truck_id])
    hours = (params[:hours] || 4).to_i

    result = AiIntegrationService.predict_temperature(truck, hours_ahead: hours)
    render_analysis_result(result)
  end

  def review_compliance
    route = Route.find(params[:route_id])

    result = AiIntegrationService.review_compliance(route)
    render_analysis_result(result)
  end

  # Insights
  def insights
    scope = AiInsight.includes(:ai_request).recent

    scope = scope.where(insight_type: params[:type]) if params[:type].present?
    scope = scope.by_severity(params[:severity]) if params[:severity].present?
    scope = scope.active if params[:status] == 'active'
    scope = scope.unacknowledged if params[:unacknowledged] == 'true'

    if params[:entity_type].present? && params[:entity_id].present?
      scope = scope.where(insightable_type: params[:entity_type], insightable_id: params[:entity_id])
    end

    insights = scope.limit(params[:limit] || 50)
    render json: insights.map { |i| serialize_insight(i) }
  end

  def show_insight
    insight = AiInsight.find(params[:id])
    render json: serialize_insight(insight, include_details: true)
  end

  def acknowledge_insight
    insight = AiInsight.find(params[:id])
    insight.acknowledge!(params[:user] || 'system')

    render json: serialize_insight(insight)
  end

  def resolve_insight
    insight = AiInsight.find(params[:id])
    insight.resolve!

    render json: serialize_insight(insight)
  end

  def dismiss_insight
    insight = AiInsight.find(params[:id])
    insight.dismiss!

    render json: serialize_insight(insight)
  end

  # Feedback
  def submit_feedback
    insight = AiInsight.find(params[:insight_id])

    feedback = AiIntegrationService.submit_feedback(
      insight,
      feedback_type: params[:feedback_type],
      rating: params[:rating],
      comments: params[:comments],
      user: params[:user]
    )

    render json: {
      id: feedback.id,
      feedback_type: feedback.feedback_type,
      rating: feedback.rating,
      created_at: feedback.created_at
    }, status: :created
  end

  # Requests log
  def requests
    scope = AiRequest.includes(:ai_provider, :ai_prompt).recent

    scope = scope.where(request_type: params[:type]) if params[:type].present?
    scope = scope.where(status: params[:status]) if params[:status].present?

    requests = scope.limit(params[:limit] || 50)
    render json: requests.map { |r| serialize_request(r) }
  end

  # Statistics
  def stats
    period = (params[:days] || 30).to_i.days
    stats = AiIntegrationService.usage_stats(period: period)

    render json: stats
  end

  # Available types
  def available_types
    render json: {
      request_types: AiRequest::REQUEST_TYPES,
      insight_types: AiInsight::INSIGHT_TYPES,
      provider_types: AiProvider::PROVIDER_TYPES,
      prompt_types: AiPrompt::PROMPT_TYPES
    }
  end

  private

  def find_entity
    case params[:entity_type]
    when 'truck', 'Truck'
      Truck.find_by(id: params[:entity_id])
    when 'route', 'Route'
      Route.find_by(id: params[:entity_id])
    when 'shipment_event', 'ShipmentEvent'
      ShipmentEvent.find_by(id: params[:entity_id])
    end
  end

  def render_analysis_result(result)
    if result[:success]
      render json: {
        request_id: result[:request].id,
        response: result[:response],
        insights: result[:request].ai_insights.map { |i| serialize_insight(i) }
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def provider_params
    params.require(:provider).permit(
      :name, :provider_type, :endpoint_url, :api_key_encrypted,
      :ai_model, :status, :rate_limit_per_minute, :max_tokens,
      :cost_per_1k_tokens
    )
  end

  def prompt_params
    params.require(:prompt).permit(
      :name, :prompt_type, :system_prompt, :user_prompt_template,
      :version, :active
    )
  end

  def serialize_provider(provider)
    {
      id: provider.id,
      name: provider.name,
      provider_type: provider.provider_type,
      endpoint_url: provider.endpoint_url,
      ai_model: provider.ai_model,
      status: provider.status,
      rate_limit_per_minute: provider.rate_limit_per_minute,
      max_tokens: provider.max_tokens,
      cost_per_1k_tokens: provider.cost_per_1k_tokens,
      available: provider.available?,
      created_at: provider.created_at
    }
  end

  def serialize_prompt(prompt)
    {
      id: prompt.id,
      name: prompt.name,
      prompt_type: prompt.prompt_type,
      system_prompt: prompt.system_prompt,
      user_prompt_template: prompt.user_prompt_template,
      variables: prompt.variables_list,
      version: prompt.version,
      active: prompt.active,
      created_at: prompt.created_at
    }
  end

  def serialize_insight(insight, include_details: false)
    data = {
      id: insight.id,
      insight_type: insight.insight_type,
      title: insight.title,
      summary: insight.summary,
      confidence_score: insight.confidence_score,
      severity: insight.severity,
      status: insight.status,
      acknowledged_at: insight.acknowledged_at,
      acknowledged_by: insight.acknowledged_by,
      entity_type: insight.insightable_type,
      entity_id: insight.insightable_id,
      created_at: insight.created_at
    }

    data[:details] = insight.details_hash if include_details
    data[:request_id] = insight.ai_request_id if include_details

    data
  end

  def serialize_request(request)
    {
      id: request.id,
      request_type: request.request_type,
      status: request.status,
      provider: request.ai_provider&.name,
      prompt: request.ai_prompt&.name,
      entity_type: request.requestable_type,
      entity_id: request.requestable_id,
      tokens_used: request.tokens_used,
      cost: request.cost,
      latency_ms: request.latency_ms,
      error_message: request.error_message,
      created_at: request.created_at
    }
  end
end
