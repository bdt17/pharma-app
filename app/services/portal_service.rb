class PortalService
  class << self
    def create_share(route:, portal_user:, access_level: 'tracking', expires_in: nil)
      new.create_share(route, portal_user, access_level, expires_in)
    end

    def get_shipment_view(share_token)
      new.get_shipment_view(share_token)
    end

    def trigger_webhooks(event:, payload:)
      new.trigger_webhooks(event, payload)
    end

    def customer_dashboard(portal_user)
      new.customer_dashboard(portal_user)
    end

    def partner_analytics(portal_user)
      new.partner_analytics(portal_user)
    end
  end

  def create_share(route, portal_user, access_level, expires_in)
    expires_at = expires_in ? Time.current + expires_in : nil

    share = ShipmentShare.create!(
      route: route,
      portal_user: portal_user,
      access_level: access_level,
      expires_at: expires_at,
      accessed_count: 0
    )

    {
      share_id: share.id,
      share_token: share.share_token,
      public_url: share.public_url,
      access_level: share.access_level,
      expires_at: share.expires_at
    }
  end

  def get_shipment_view(share_token)
    share = ShipmentShare.by_token(share_token).first

    return { error: 'Share not found' } unless share
    return { error: 'Share expired' } if share.expired?

    share.record_access!
    route = share.route
    truck = route.truck

    view = {
      shipment: {
        id: route.id,
        name: route.name,
        origin: route.origin,
        destination: route.destination,
        status: route.status,
        progress: route.progress_percentage,
        started_at: route.started_at,
        estimated_arrival: route.estimated_arrival
      },
      access_level: share.access_level
    }

    if share.can_view_location? && truck
      latest_telemetry = truck.latest_telemetry
      view[:location] = if latest_telemetry
        {
          latitude: latest_telemetry.latitude,
          longitude: latest_telemetry.longitude,
          speed_kph: latest_telemetry.speed_kph,
          updated_at: latest_telemetry.recorded_at
        }
      end

      view[:waypoints] = route.waypoints.map do |wp|
        {
          position: wp.position,
          site_name: wp.site&.name,
          status: wp.status,
          arrival_time: wp.arrival_time,
          departure_time: wp.departure_time
        }
      end
    end

    if share.can_view_temperature? && truck
      view[:temperature] = {
        current: truck.latest_telemetry&.temperature_c || truck.monitorings.order(recorded_at: :desc).first&.temperature,
        min: truck.min_temp,
        max: truck.max_temp,
        status: truck.temperature_status,
        last_reading: truck.latest_telemetry&.recorded_at
      }

      # Recent temperature history
      view[:temperature_history] = recent_temperatures(truck, 24)
    end

    if share.can_view_documents?
      view[:documents] = {
        compliance_available: true,
        signatures_count: route.signatures.count
      }
    end

    if share.can_view_compliance?
      view[:compliance] = {
        chain_verified: verify_chain_status(truck),
        deviations_count: count_deviations(truck, route)
      }
    end

    view
  end

  def trigger_webhooks(event, payload)
    subscriptions = WebhookSubscription.for_event(event)
    results = []

    subscriptions.each do |subscription|
      result = deliver_webhook(subscription, event, payload)
      results << {
        subscription_id: subscription.id,
        url: subscription.url,
        success: result[:success],
        status_code: result[:status_code]
      }
    end

    results
  end

  def customer_dashboard(portal_user)
    shares = portal_user.shipment_shares.active.includes(route: :truck)

    {
      user: {
        id: portal_user.id,
        name: portal_user.name,
        organization: portal_user.organization_name
      },
      active_shipments: shares.select { |s| s.route.status == 'in_progress' }.map do |share|
        shipment_summary(share)
      end,
      recent_shipments: shares.select { |s| s.route.status == 'completed' }.first(10).map do |share|
        shipment_summary(share)
      end,
      alerts: customer_alerts(shares),
      stats: customer_stats(shares)
    }
  end

  def partner_analytics(portal_user)
    shares = portal_user.shipment_shares.includes(route: [:truck, :waypoints])
    routes = shares.map(&:route)

    {
      user: {
        id: portal_user.id,
        name: portal_user.name,
        organization: portal_user.organization_name,
        role: portal_user.role
      },
      summary: {
        total_shipments: routes.count,
        in_progress: routes.count { |r| r.status == 'in_progress' },
        completed: routes.count { |r| r.status == 'completed' },
        with_excursions: count_routes_with_excursions(routes)
      },
      performance: {
        on_time_rate: calculate_on_time_rate(routes),
        temperature_compliance_rate: calculate_temp_compliance_rate(routes),
        average_transit_time_hours: calculate_avg_transit_time(routes)
      },
      recent_activity: recent_activity(routes),
      webhooks: {
        active: portal_user.webhook_subscriptions.active.count,
        failed: portal_user.webhook_subscriptions.where(status: 'failed').count
      }
    }
  end

  private

  def recent_temperatures(truck, hours)
    readings = []

    if truck.respond_to?(:telemetry_readings)
      truck.telemetry_readings
           .where('recorded_at > ?', hours.hours.ago)
           .order(recorded_at: :asc)
           .pluck(:recorded_at, :temperature_c)
           .each do |recorded_at, temp|
        readings << { timestamp: recorded_at, temperature: temp } if temp
      end
    end

    readings.last(50)
  end

  def verify_chain_status(truck)
    return true unless truck
    result = ShipmentEvent.verify_chain(truck.id)
    result[:valid]
  end

  def count_deviations(truck, route)
    return 0 unless truck
    events = route.respond_to?(:shipment_events) ? route.shipment_events : truck.shipment_events
    events.where(deviation_reported: true).count
  end

  def deliver_webhook(subscription, event, payload)
    webhook_payload = {
      event: event,
      timestamp: Time.current.iso8601,
      data: payload
    }

    signature = subscription.signature_for(webhook_payload)

    begin
      response = Net::HTTP.post(
        URI(subscription.url),
        webhook_payload.to_json,
        {
          'Content-Type' => 'application/json',
          'X-Webhook-Signature' => signature,
          'X-Webhook-Event' => event
        }
      )

      success = response.code.to_i.between?(200, 299)
      success ? subscription.record_success! : subscription.record_failure!

      { success: success, status_code: response.code.to_i }
    rescue => e
      subscription.record_failure!
      { success: false, error: e.message }
    end
  end

  def shipment_summary(share)
    route = share.route
    truck = route.truck

    {
      share_token: share.share_token,
      route_id: route.id,
      name: route.name,
      origin: route.origin,
      destination: route.destination,
      status: route.status,
      progress: route.progress_percentage,
      current_temperature: truck&.latest_telemetry&.temperature_c,
      temperature_status: truck&.temperature_status,
      started_at: route.started_at,
      estimated_arrival: route.estimated_arrival,
      access_level: share.access_level
    }
  end

  def customer_alerts(shares)
    alerts = []

    shares.each do |share|
      route = share.route
      truck = route.truck
      next unless truck && route.status == 'in_progress'

      # Temperature alerts
      temp = truck.latest_telemetry&.temperature_c || truck.monitorings.order(recorded_at: :desc).first&.temperature
      if temp && truck.out_of_range?(temp)
        alerts << {
          type: 'temperature',
          severity: 'high',
          shipment: route.name,
          message: "Temperature #{temp}°C out of range"
        }
      end

      # Delay alerts
      if route.max_transit_hours && route.started_at
        elapsed = (Time.current - route.started_at) / 1.hour
        if elapsed > route.max_transit_hours * 0.9
          alerts << {
            type: 'delay',
            severity: elapsed > route.max_transit_hours ? 'high' : 'medium',
            shipment: route.name,
            message: "Shipment approaching time limit"
          }
        end
      end
    end

    alerts.first(10)
  end

  def customer_stats(shares)
    routes = shares.map(&:route)
    completed = routes.select { |r| r.status == 'completed' }

    {
      total_shipments: routes.count,
      active_shipments: routes.count { |r| r.status == 'in_progress' },
      completed_shipments: completed.count,
      on_time_deliveries: completed.count { |r| r.max_transit_hours.nil? || within_time_limit?(r) }
    }
  end

  def within_time_limit?(route)
    return true unless route.started_at && route.completed_at && route.max_transit_hours
    (route.completed_at - route.started_at) / 1.hour <= route.max_transit_hours
  end

  def count_routes_with_excursions(routes)
    routes.count do |route|
      truck = route.truck
      next false unless truck
      truck.monitorings.where('recorded_at >= ?', route.started_at || 30.days.ago).any? { |m| truck.out_of_range?(m.temperature) }
    end
  end

  def calculate_on_time_rate(routes)
    completed = routes.select { |r| r.status == 'completed' && r.max_transit_hours }
    return 100.0 if completed.empty?

    on_time = completed.count { |r| within_time_limit?(r) }
    (on_time.to_f / completed.count * 100).round(1)
  end

  def calculate_temp_compliance_rate(routes)
    with_data = routes.select { |r| r.truck&.monitorings&.any? }
    return 100.0 if with_data.empty?

    compliant = with_data.count do |route|
      truck = route.truck
      readings = truck.monitorings.where('recorded_at >= ?', route.started_at || 30.days.ago)
      readings.none? { |m| truck.out_of_range?(m.temperature) }
    end

    (compliant.to_f / with_data.count * 100).round(1)
  end

  def calculate_avg_transit_time(routes)
    completed = routes.select { |r| r.status == 'completed' && r.started_at && r.completed_at }
    return 0 if completed.empty?

    total_hours = completed.sum { |r| (r.completed_at - r.started_at) / 1.hour }
    (total_hours / completed.count).round(1)
  end

  def recent_activity(routes)
    events = []

    routes.each do |route|
      truck = route.truck
      next unless truck

      truck.shipment_events.order(recorded_at: :desc).limit(5).each do |event|
        events << {
          route_name: route.name,
          event_type: event.event_type,
          description: event.description,
          recorded_at: event.recorded_at
        }
      end
    end

    events.sort_by { |e| e[:recorded_at] }.reverse.first(20)
  end
end
