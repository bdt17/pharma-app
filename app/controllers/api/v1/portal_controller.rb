class Api::V1::PortalController < Api::BaseController
  skip_before_action :authenticate_api_token, only: [:track]

  # Public tracking endpoint
  def track
    share_token = params[:token]

    unless share_token.present?
      return render json: { error: 'Token required' }, status: :bad_request
    end

    view = PortalService.get_shipment_view(share_token)

    if view[:error]
      render json: view, status: :not_found
    else
      render json: view
    end
  end

  # Portal user management
  def users
    users = PortalUser.order(created_at: :desc)
    users = users.where(role: params[:role]) if params[:role].present?
    users = users.where(status: params[:status]) if params[:status].present?
    users = users.limit(params[:limit] || 50)

    render json: users.map { |u| serialize_user(u) }
  end

  def show_user
    user = PortalUser.find(params[:id])
    render json: serialize_user(user, include_permissions: true)
  end

  def create_user
    user = PortalUser.new(user_params)
    user.status ||= 'active'

    if user.save
      render json: serialize_user(user, include_api_key: true), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_user
    user = PortalUser.find(params[:id])

    if user.update(user_params)
      render json: serialize_user(user)
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def regenerate_key
    user = PortalUser.find(params[:id])
    new_key = user.regenerate_api_key!

    render json: { api_key: new_key, message: 'API key regenerated' }
  end

  # Shipment sharing
  def shares
    shares = ShipmentShare.includes(:route, :portal_user).order(created_at: :desc)
    shares = shares.where(portal_user_id: params[:user_id]) if params[:user_id].present?
    shares = shares.where(route_id: params[:route_id]) if params[:route_id].present?
    shares = shares.active if params[:active] == 'true'
    shares = shares.limit(params[:limit] || 50)

    render json: shares.map { |s| serialize_share(s) }
  end

  def create_share
    route = Route.find(params[:route_id])
    portal_user = PortalUser.find(params[:portal_user_id])

    expires_in = params[:expires_in_hours] ? params[:expires_in_hours].to_i.hours : nil

    result = PortalService.create_share(
      route: route,
      portal_user: portal_user,
      access_level: params[:access_level] || 'tracking',
      expires_in: expires_in
    )

    render json: result, status: :created
  end

  def revoke_share
    share = ShipmentShare.find(params[:id])
    share.update!(expires_at: Time.current)

    render json: { message: 'Share revoked', share: serialize_share(share) }
  end

  # Customer/Partner dashboards
  def customer_dashboard
    user = PortalUser.find(params[:user_id])
    dashboard = PortalService.customer_dashboard(user)
    render json: dashboard
  end

  def partner_analytics
    user = PortalUser.find(params[:user_id])
    analytics = PortalService.partner_analytics(user)
    render json: analytics
  end

  # Webhook management
  def webhooks
    user = PortalUser.find(params[:user_id])
    webhooks = user.webhook_subscriptions.order(created_at: :desc)

    render json: webhooks.map { |w| serialize_webhook(w) }
  end

  def create_webhook
    user = PortalUser.find(params[:user_id])

    webhook = user.webhook_subscriptions.new(webhook_params)
    webhook.status ||= 'active'

    if webhook.save
      render json: serialize_webhook(webhook, include_secret: true), status: :created
    else
      render json: { errors: webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_webhook
    webhook = WebhookSubscription.find(params[:id])

    if webhook.update(webhook_params)
      render json: serialize_webhook(webhook)
    else
      render json: { errors: webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def delete_webhook
    webhook = WebhookSubscription.find(params[:id])
    webhook.destroy

    render json: { message: 'Webhook deleted' }
  end

  def test_webhook
    webhook = WebhookSubscription.find(params[:id])

    test_payload = {
      test: true,
      message: 'Webhook test from PharmaTransport',
      timestamp: Time.current.iso8601
    }

    results = PortalService.trigger_webhooks(event: 'test', payload: test_payload)
    result = results.find { |r| r[:subscription_id] == webhook.id }

    if result&.dig(:success)
      render json: { success: true, message: 'Webhook test successful' }
    else
      render json: { success: false, message: 'Webhook test failed' }, status: :unprocessable_entity
    end
  end

  def available_events
    render json: { events: WebhookSubscription::EVENTS }
  end

  private

  def user_params
    params.require(:user).permit(:email, :name, :role, :organization_name, :organization_type, :status, permissions: [])
  end

  def webhook_params
    params.require(:webhook).permit(:url, :status, events: [])
  end

  def serialize_user(user, include_permissions: false, include_api_key: false)
    data = {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      organization_name: user.organization_name,
      organization_type: user.organization_type,
      status: user.status,
      last_login_at: user.last_login_at,
      created_at: user.created_at
    }

    data[:permissions] = user.permissions_list if include_permissions
    data[:api_key] = user.api_key if include_api_key

    data
  end

  def serialize_share(share)
    {
      id: share.id,
      share_token: share.share_token,
      public_url: share.public_url,
      route_id: share.route_id,
      route_name: share.route.name,
      portal_user_id: share.portal_user_id,
      portal_user_name: share.portal_user.name,
      access_level: share.access_level,
      expires_at: share.expires_at,
      expired: share.expired?,
      accessed_count: share.accessed_count,
      last_accessed_at: share.last_accessed_at,
      created_at: share.created_at
    }
  end

  def serialize_webhook(webhook, include_secret: false)
    data = {
      id: webhook.id,
      url: webhook.url,
      events: webhook.events_list,
      status: webhook.status,
      failure_count: webhook.failure_count,
      last_triggered_at: webhook.last_triggered_at,
      created_at: webhook.created_at
    }

    data[:secret] = webhook.secret if include_secret

    data
  end
end
