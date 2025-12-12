class Api::V1::ComplianceController < Api::BaseController
  def verify_shipment
    route = Route.find(params[:route_id])
    result = ComplianceService.verify_shipment_compliance(route)
    render json: result
  end

  def report
    route = Route.find(params[:route_id])
    report = ComplianceService.generate_compliance_report(route)
    render json: report
  end

  def verify_chain
    truck = Truck.find(params[:truck_id])
    route = params[:route_id].present? ? Route.find(params[:route_id]) : nil
    result = ComplianceService.verify_chain_of_custody(truck, route: route)
    render json: result
  end

  def deviation_report
    event = ShipmentEvent.find(params[:event_id])

    unless params[:description].present?
      return render json: { error: 'description required' }, status: :bad_request
    end

    record = ComplianceService.create_deviation_report(
      event: event,
      description: params[:description],
      reporter: params[:reporter] || 'API User',
      justification: params[:justification]
    )

    render json: serialize_compliance_record(record), status: :created
  end

  def audit_trail
    auditable = find_auditable
    format = params[:format]&.to_sym || :json

    result = ComplianceService.export_audit_trail(auditable: auditable, format: format)

    if format == :csv
      send_data result, filename: "audit_trail_#{auditable.class.name}_#{auditable.id}.csv", type: 'text/csv'
    else
      render json: result
    end
  end

  def records
    records = ComplianceRecord.order(created_at: :desc)
    records = records.by_type(params[:type]) if params[:type].present?
    records = records.where(status: params[:status]) if params[:status].present?
    records = records.where(reference_type: params[:reference_type]) if params[:reference_type].present?
    records = records.limit(params[:limit] || 50)

    render json: records.map { |r| serialize_compliance_record(r) }
  end

  def show_record
    record = ComplianceRecord.find(params[:id])
    render json: serialize_compliance_record(record, include_evidence: true)
  end

  def approve_record
    record = ComplianceRecord.find(params[:id])

    unless record.status == 'pending' || record.status == 'in_review'
      return render json: { error: "Cannot approve record in #{record.status} status" }, status: :unprocessable_entity
    end

    record.approve!(verified_by: params[:verified_by] || 'API User')
    render json: serialize_compliance_record(record)
  end

  def reject_record
    record = ComplianceRecord.find(params[:id])

    unless record.status == 'pending' || record.status == 'in_review'
      return render json: { error: "Cannot reject record in #{record.status} status" }, status: :unprocessable_entity
    end

    record.reject!(verified_by: params[:verified_by] || 'API User', reason: params[:reason])
    render json: serialize_compliance_record(record)
  end

  def add_evidence
    record = ComplianceRecord.find(params[:id])

    unless params[:evidence].present?
      return render json: { error: 'evidence required' }, status: :bad_request
    end

    record.add_evidence(params[:evidence].to_unsafe_h)
    render json: serialize_compliance_record(record, include_evidence: true)
  end

  def signatures
    signable = find_auditable
    signatures = Signature.for_record(signable.class.name, signable.id)

    render json: signatures.map { |s| serialize_signature(s) }
  end

  def create_signature
    signable = find_auditable

    signature = signable.signatures.new(signature_params)
    signature.signed_at ||= Time.current
    signature.ip_address = request.remote_ip

    if signature.save
      render json: serialize_signature(signature), status: :created
    else
      render json: { errors: signature.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def gdp_requirements
    render json: {
      requirements: ComplianceService::GDP_REQUIREMENTS.map do |key, req|
        req.merge(key: key.to_s)
      end
    }
  end

  private

  def find_auditable
    if params[:truck_id].present?
      Truck.find(params[:truck_id])
    elsif params[:route_id].present?
      Route.find(params[:route_id])
    elsif params[:event_id].present?
      ShipmentEvent.find(params[:event_id])
    else
      raise ActiveRecord::RecordNotFound, 'No auditable record specified'
    end
  end

  def signature_params
    params.require(:signature).permit(:signer_name, :signer_role, :signer_email, :signature_data, :device_info)
  end

  def serialize_compliance_record(record, include_evidence: false)
    data = {
      id: record.id,
      record_type: record.record_type,
      reference_type: record.reference_type,
      reference_id: record.reference_id,
      status: record.status,
      verified_by: record.verified_by,
      verified_at: record.verified_at,
      expires_at: record.expires_at,
      expired: record.expired?,
      expiring_soon: record.expiring_soon?,
      days_until_expiration: record.days_until_expiration,
      meets_requirements: record.meets_requirements?,
      notes: record.notes,
      created_at: record.created_at,
      updated_at: record.updated_at
    }

    if include_evidence
      data[:requirements] = record.requirements_list
      data[:evidence] = record.evidence_list
    end

    data
  end

  def serialize_signature(signature)
    {
      id: signature.id,
      signable_type: signature.signable_type,
      signable_id: signature.signable_id,
      signer_name: signature.signer_name,
      signer_role: signature.signer_role,
      signer_email: signature.signer_email,
      signed_at: signature.signed_at,
      signature_hash: signature.signature_hash,
      display_info: signature.display_info
    }
  end
end
