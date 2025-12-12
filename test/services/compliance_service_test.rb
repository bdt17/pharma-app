require "test_helper"

class ComplianceServiceTest < ActiveSupport::TestCase
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
      status: "completed",
      started_at: 6.hours.ago,
      completed_at: 1.hour.ago,
      max_transit_hours: 8
    )
  end

  test "verify_shipment_compliance returns compliance status" do
    result = ComplianceService.verify_shipment_compliance(@route)

    assert result[:route_id].present?
    assert result[:compliance_status].in?(%w[compliant non_compliant])
    assert result[:findings].is_a?(Array)
    assert_not_nil result[:overall_passed]
  end

  test "verify_shipment_compliance detects temperature excursions" do
    # Create out-of-range reading
    @truck.monitorings.create!(
      temperature: 12.0,  # Above max of 8
      power_status: 'on',
      recorded_at: 3.hours.ago
    )

    result = ComplianceService.verify_shipment_compliance(@route)

    temp_finding = result[:findings].find { |f| f[:check] == 'temperature' }
    assert_not temp_finding[:passed]
    assert temp_finding[:excursion_count] > 0
  end

  test "verify_shipment_compliance checks time window" do
    @route.update!(
      max_transit_hours: 4,
      started_at: 6.hours.ago,
      completed_at: 1.hour.ago
    )  # 5 hours, exceeds 4 hour limit

    result = ComplianceService.verify_shipment_compliance(@route)

    time_finding = result[:findings].find { |f| f[:check] == 'time_window' }
    assert_not time_finding[:passed]
  end

  test "generate_compliance_report returns comprehensive report" do
    report = ComplianceService.generate_compliance_report(@route)

    assert report[:report_id].present?
    assert report[:route].present?
    assert report[:temperature_log].is_a?(Array)
    assert report[:chain_of_custody].is_a?(Array)
    assert report[:compliance_verification].present?
  end

  test "verify_chain_of_custody validates event chain" do
    # Create events with proper chain
    event1 = @truck.shipment_events.create!(
      event_type: 'route_started',
      recorded_at: 5.hours.ago,
      recorded_by: 'driver'
    )

    event2 = @truck.shipment_events.create!(
      event_type: 'stop_arrival',
      recorded_at: 3.hours.ago,
      recorded_by: 'driver'
    )

    result = ComplianceService.verify_chain_of_custody(@truck, route: @route)

    # Result should have structure
    assert result.key?(:valid)
    assert result.key?(:events_verified) || result.key?(:message)
  end

  test "create_deviation_report creates compliance record" do
    event = @truck.shipment_events.create!(
      event_type: 'temperature_excursion',
      recorded_at: 2.hours.ago,
      recorded_by: 'system',
      temperature_c: 12.0
    )

    record = ComplianceService.create_deviation_report(
      event: event,
      description: 'Temperature exceeded threshold',
      reporter: 'QA Manager',
      justification: 'Equipment malfunction'
    )

    assert record.persisted?
    assert_equal 'deviation_report', record.record_type
    assert_equal 'pending', record.status
    assert event.reload.deviation_reported
  end

  test "export_audit_trail returns audit entries" do
    # Create some audit logs
    AuditLog.log(
      action: 'create',
      auditable: @route,
      actor: 'system'
    )

    result = ComplianceService.export_audit_trail(auditable: @route, format: :json)

    assert result[:audit_entries].is_a?(Array)
    assert result[:record_type] == 'Route'
    assert result[:record_id] == @route.id
  end

  test "export_audit_trail supports csv format" do
    AuditLog.log(
      action: 'create',
      auditable: @route,
      actor: 'system'
    )

    result = ComplianceService.export_audit_trail(auditable: @route, format: :csv)

    assert result.is_a?(String)
    assert result.include?('ID,Action,Actor')
  end
end
