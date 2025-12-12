require 'csv'

class ComplianceService
  GDP_REQUIREMENTS = {
    temperature_monitoring: {
      id: 'GDP-001',
      description: 'Continuous temperature monitoring during transport',
      evidence_type: 'telemetry_data'
    },
    chain_of_custody: {
      id: 'GDP-002',
      description: 'Complete chain of custody documentation',
      evidence_type: 'shipment_events'
    },
    calibration: {
      id: 'GDP-003',
      description: 'Calibrated monitoring equipment',
      evidence_type: 'calibration_certificate'
    },
    training: {
      id: 'GDP-004',
      description: 'Personnel training documentation',
      evidence_type: 'training_record'
    },
    deviation_handling: {
      id: 'GDP-005',
      description: 'Documented deviation handling procedures',
      evidence_type: 'deviation_report'
    }
  }.freeze

  class << self
    def verify_shipment_compliance(route)
      new.verify_shipment_compliance(route)
    end

    def generate_compliance_report(route)
      new.generate_compliance_report(route)
    end

    def verify_chain_of_custody(truck, route: nil)
      new.verify_chain_of_custody(truck, route)
    end

    def create_deviation_report(event:, description:, reporter:, justification: nil)
      new.create_deviation_report(event, description, reporter, justification)
    end

    def export_audit_trail(auditable:, format: :json)
      new.export_audit_trail(auditable, format)
    end
  end

  def verify_shipment_compliance(route)
    findings = []
    passed = true

    # Check temperature compliance
    temp_check = check_temperature_compliance(route)
    findings << temp_check
    passed = false unless temp_check[:passed]

    # Check chain of custody
    chain_check = check_chain_of_custody(route)
    findings << chain_check
    passed = false unless chain_check[:passed]

    # Check required signatures
    sig_check = check_required_signatures(route)
    findings << sig_check
    passed = false unless sig_check[:passed]

    # Check time windows
    time_check = check_time_compliance(route)
    findings << time_check
    passed = false unless time_check[:passed]

    # Log compliance check
    AuditLog.log_compliance_check(
      record: route,
      passed: passed,
      findings: findings
    )

    {
      route_id: route.id,
      route_name: route.name,
      compliance_status: passed ? 'compliant' : 'non_compliant',
      checked_at: Time.current,
      findings: findings,
      overall_passed: passed
    }
  end

  def generate_compliance_report(route)
    truck = route.truck
    events = route.shipment_events.order(recorded_at: :asc) if route.respond_to?(:shipment_events)
    events ||= truck&.shipment_events&.order(recorded_at: :asc) || []

    {
      report_id: SecureRandom.uuid,
      generated_at: Time.current,
      route: {
        id: route.id,
        name: route.name,
        origin: route.origin,
        destination: route.destination,
        status: route.status,
        started_at: route.started_at,
        completed_at: route.completed_at
      },
      truck: truck ? {
        id: truck.id,
        name: truck.name,
        temp_range: "#{truck.min_temp}°C - #{truck.max_temp}°C"
      } : nil,
      temperature_log: generate_temperature_log(truck, route),
      chain_of_custody: generate_chain_of_custody_log(events),
      signatures: collect_signatures(route, events),
      deviations: collect_deviations(events),
      compliance_verification: verify_shipment_compliance(route),
      audit_trail: AuditLog.for_record('Route', route.id).chronological.map { |log| serialize_audit_log(log) }
    }
  end

  def verify_chain_of_custody(truck, route = nil)
    events = if route&.respond_to?(:shipment_events)
               route.shipment_events.order(recorded_at: :asc)
             else
               truck.shipment_events.order(recorded_at: :asc)
             end

    return { valid: true, message: 'No events to verify' } if events.empty?

    # Verify hash chain integrity
    valid = true
    broken_at = nil
    previous_hash = nil

    events.each do |event|
      if previous_hash && event.previous_hash != previous_hash
        valid = false
        broken_at = event.id
        break
      end
      previous_hash = event.event_hash
    end

    # Log verification
    AuditLog.log_chain_verification(
      truck: truck,
      verified: valid,
      metadata: { route_id: route&.id, events_count: events.count, broken_at: broken_at }
    )

    {
      valid: valid,
      events_verified: events.count,
      first_event: events.first&.recorded_at,
      last_event: events.last&.recorded_at,
      broken_at_event_id: broken_at,
      message: valid ? 'Chain of custody verified' : 'Chain integrity compromised'
    }
  end

  def create_deviation_report(event, description, reporter, justification = nil)
    event.update!(
      deviation_reported: true,
      deviation_justification: justification
    )

    record = ComplianceRecord.create!(
      record_type: 'deviation_report',
      reference_type: 'ShipmentEvent',
      reference_id: event.id.to_s,
      status: 'pending',
      requirements: [{
        id: 'DEV-001',
        description: 'Root cause analysis',
        required: true
      }, {
        id: 'DEV-002',
        description: 'Corrective action plan',
        required: true
      }],
      evidence: [{
        type: 'initial_report',
        description: description,
        reporter: reporter,
        reported_at: Time.current.iso8601
      }],
      notes: "Deviation reported for event #{event.id}: #{description}"
    )

    AuditLog.log(
      action: 'deviation_reported',
      auditable: event,
      actor: reporter,
      metadata: { deviation_record_id: record.id, description: description }
    )

    record
  end

  def export_audit_trail(auditable, format)
    logs = AuditLog.for_record(auditable.class.name, auditable.id).chronological

    case format
    when :json
      {
        exported_at: Time.current,
        record_type: auditable.class.name,
        record_id: auditable.id,
        audit_entries: logs.map { |log| serialize_audit_log(log) }
      }
    when :csv
      generate_csv(logs)
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  private

  def check_temperature_compliance(route)
    truck = route.truck
    return { check: 'temperature', passed: true, message: 'No truck assigned' } unless truck

    excursions = []

    # Check telemetry readings
    if truck.respond_to?(:telemetry_readings)
      truck.telemetry_readings.where('recorded_at >= ?', route.started_at || 7.days.ago).find_each do |reading|
        next unless reading.temperature_c
        if reading.temperature_c < truck.min_temp.to_f || reading.temperature_c > truck.max_temp.to_f
          excursions << {
            timestamp: reading.recorded_at,
            temperature: reading.temperature_c,
            source: 'telemetry'
          }
        end
      end
    end

    # Check monitoring readings
    truck.monitorings.where('recorded_at >= ?', route.started_at || 7.days.ago).find_each do |reading|
      if truck.out_of_range?(reading.temperature)
        excursions << {
          timestamp: reading.recorded_at,
          temperature: reading.temperature,
          source: 'monitoring'
        }
      end
    end

    {
      check: 'temperature',
      passed: excursions.empty?,
      excursion_count: excursions.count,
      excursions: excursions.first(10),
      message: excursions.empty? ? 'All readings within range' : "#{excursions.count} excursion(s) detected"
    }
  end

  def check_chain_of_custody(route)
    verification = verify_chain_of_custody(route.truck, route)

    {
      check: 'chain_of_custody',
      passed: verification[:valid],
      events_count: verification[:events_verified],
      message: verification[:message]
    }
  end

  def check_required_signatures(route)
    events = route.respond_to?(:shipment_events) ? route.shipment_events : []
    events = route.truck&.shipment_events || [] if events.empty?

    required_events = events.where(signature_required: true)
    unsigned = required_events.where(signature_captured: false)

    {
      check: 'signatures',
      passed: unsigned.empty?,
      required_count: required_events.count,
      captured_count: required_events.count - unsigned.count,
      missing_count: unsigned.count,
      message: unsigned.empty? ? 'All required signatures captured' : "#{unsigned.count} signature(s) missing"
    }
  end

  def check_time_compliance(route)
    return { check: 'time_window', passed: true, message: 'No time constraints' } unless route.max_transit_hours

    if route.completed_at && route.started_at
      actual_hours = (route.completed_at - route.started_at) / 1.hour
      passed = actual_hours <= route.max_transit_hours

      {
        check: 'time_window',
        passed: passed,
        max_hours: route.max_transit_hours,
        actual_hours: actual_hours.round(1),
        message: passed ? 'Delivered within time window' : "Exceeded by #{(actual_hours - route.max_transit_hours).round(1)} hours"
      }
    else
      { check: 'time_window', passed: true, message: 'Route not yet completed' }
    end
  end

  def generate_temperature_log(truck, route)
    return [] unless truck

    readings = []
    start_time = route.started_at || 7.days.ago

    if truck.respond_to?(:telemetry_readings)
      truck.telemetry_readings.where('recorded_at >= ?', start_time).order(recorded_at: :asc).each do |r|
        readings << {
          timestamp: r.recorded_at,
          temperature: r.temperature_c,
          humidity: r.humidity,
          source: 'telemetry',
          in_range: r.temperature_c.nil? || (r.temperature_c >= truck.min_temp.to_f && r.temperature_c <= truck.max_temp.to_f)
        }
      end
    end

    readings
  end

  def generate_chain_of_custody_log(events)
    events.map do |event|
      {
        id: event.id,
        event_type: event.event_type,
        description: event.description,
        recorded_at: event.recorded_at,
        recorded_by: event.recorded_by,
        location: event.latitude && event.longitude ? { lat: event.latitude, lng: event.longitude } : nil,
        temperature: event.temperature_c,
        event_hash: event.event_hash,
        previous_hash: event.previous_hash,
        signature_required: event.signature_required,
        signature_captured: event.signature_captured,
        deviation_reported: event.deviation_reported
      }
    end
  end

  def collect_signatures(route, events)
    signatures = Signature.for_record('Route', route.id)

    events.each do |event|
      signatures = signatures.or(Signature.for_record('ShipmentEvent', event.id))
    end

    signatures.map do |sig|
      {
        id: sig.id,
        signer_name: sig.signer_name,
        signer_role: sig.signer_role,
        signed_at: sig.signed_at,
        signature_hash: sig.signature_hash
      }
    end
  end

  def collect_deviations(events)
    events.where(deviation_reported: true).map do |event|
      {
        event_id: event.id,
        event_type: event.event_type,
        recorded_at: event.recorded_at,
        justification: event.deviation_justification
      }
    end
  end

  def serialize_audit_log(log)
    {
      id: log.id,
      action: log.action,
      actor: log.actor_name,
      recorded_at: log.recorded_at,
      changes: log.change_data_hash,
      metadata: log.metadata_hash
    }
  end

  def generate_csv(logs)
    CSV.generate do |csv|
      csv << ['ID', 'Action', 'Actor', 'Recorded At', 'IP Address', 'Changes']
      logs.each do |log|
        csv << [log.id, log.action, log.actor_name, log.recorded_at, log.ip_address, log.change_data_hash.to_json]
      end
    end
  end
end
