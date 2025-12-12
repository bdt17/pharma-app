require "test_helper"

class PortalServiceTest < ActiveSupport::TestCase
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
    @portal_user = PortalUser.create!(
      email: "customer@example.com",
      name: "Test Customer",
      role: "customer",
      organization_name: "Test Corp",
      status: "active"
    )
  end

  test "create_share generates share with token" do
    result = PortalService.create_share(
      route: @route,
      portal_user: @portal_user,
      access_level: 'tracking'
    )

    assert result[:share_token].present?
    assert result[:public_url].present?
    assert_equal 'tracking', result[:access_level]
  end

  test "create_share with expiration" do
    result = PortalService.create_share(
      route: @route,
      portal_user: @portal_user,
      expires_in: 24.hours
    )

    share = ShipmentShare.find_by(share_token: result[:share_token])
    assert share.expires_at.present?
    assert share.expires_at > Time.current
  end

  test "get_shipment_view returns shipment data" do
    share = ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'tracking'
    )

    view = PortalService.get_shipment_view(share.share_token)

    assert view[:shipment].present?
    assert_equal @route.id, view[:shipment][:id]
    assert_equal @route.name, view[:shipment][:name]
    assert_equal 'tracking', view[:access_level]
  end

  test "get_shipment_view returns error for invalid token" do
    view = PortalService.get_shipment_view('invalid_token')

    assert view[:error].present?
  end

  test "get_shipment_view returns error for expired share" do
    share = ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'tracking',
      expires_at: 1.hour.ago
    )

    view = PortalService.get_shipment_view(share.share_token)

    assert view[:error].present?
    assert_equal 'Share expired', view[:error]
  end

  test "get_shipment_view includes temperature for tracking level" do
    share = ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'tracking'
    )

    @truck.monitorings.create!(temperature: 5.0, power_status: 'on', recorded_at: Time.current)

    view = PortalService.get_shipment_view(share.share_token)

    assert view[:temperature].present?
    assert_equal 5.0, view[:temperature][:current]
  end

  test "get_shipment_view excludes temperature for basic level" do
    share = ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'basic'
    )

    view = PortalService.get_shipment_view(share.share_token)

    assert_nil view[:temperature]
    assert_nil view[:location]
  end

  test "customer_dashboard returns user shipments" do
    ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'tracking'
    )

    dashboard = PortalService.customer_dashboard(@portal_user)

    assert dashboard[:user].present?
    assert dashboard[:active_shipments].is_a?(Array)
    assert dashboard[:stats].present?
  end

  test "partner_analytics returns analytics data" do
    ShipmentShare.create!(
      route: @route,
      portal_user: @portal_user,
      access_level: 'full'
    )

    analytics = PortalService.partner_analytics(@portal_user)

    assert analytics[:summary].present?
    assert analytics[:performance].present?
    assert_equal 1, analytics[:summary][:total_shipments]
  end
end
