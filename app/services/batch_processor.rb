class BatchProcessor
  class << self
    # Process telemetry data in batches for high-volume ingestion
    def process_telemetry_batch(truck_id, readings)
      return { processed: 0, errors: [] } if readings.blank?

      truck = Truck.find_by(id: truck_id)
      return { processed: 0, errors: ['Truck not found'] } unless truck

      processed = 0
      errors = []

      # Use bulk insert for efficiency
      records = readings.map do |reading|
        {
          truck_id: truck_id,
          temperature_c: reading[:temperature_c] || reading[:temperature],
          humidity: reading[:humidity],
          latitude: reading[:latitude] || reading[:lat],
          longitude: reading[:longitude] || reading[:lng],
          speed_kph: reading[:speed_kph] || reading[:speed],
          recorded_at: parse_timestamp(reading[:recorded_at] || reading[:timestamp]),
          raw_payload: reading.to_json,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      begin
        TelemetryReading.insert_all(records)
        processed = records.size

        # Check for alerts on latest reading
        latest = records.max_by { |r| r[:recorded_at] }
        if latest && truck.out_of_range?(latest[:temperature_c])
          trigger_temperature_alert(truck, latest[:temperature_c])
        end

        # Invalidate cache
        CacheService.invalidate_truck(truck_id)
      rescue => e
        errors << e.message
      end

      { processed: processed, errors: errors }
    end

    # Batch process monitoring data
    def process_monitoring_batch(truck_id, readings)
      return { processed: 0, errors: [] } if readings.blank?

      truck = Truck.find_by(id: truck_id)
      return { processed: 0, errors: ['Truck not found'] } unless truck

      records = readings.map do |reading|
        {
          truck_id: truck_id,
          temperature: reading[:temperature],
          power_status: reading[:power_status] || 'on',
          recorded_at: parse_timestamp(reading[:recorded_at] || reading[:timestamp]),
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      begin
        Monitoring.insert_all(records)
        CacheService.invalidate_truck(truck_id)
        { processed: records.size, errors: [] }
      rescue => e
        { processed: 0, errors: [e.message] }
      end
    end

    # Batch process shipment events
    def process_events_batch(truck_id, events)
      return { processed: 0, errors: [] } if events.blank?

      truck = Truck.find_by(id: truck_id)
      return { processed: 0, errors: ['Truck not found'] } unless truck

      processed = 0
      errors = []

      # Events need to maintain hash chain, so process sequentially
      events.each do |event_data|
        begin
          event = ShipmentEvent.new(
            truck: truck,
            route_id: event_data[:route_id],
            event_type: event_data[:event_type],
            description: event_data[:description],
            latitude: event_data[:latitude],
            longitude: event_data[:longitude],
            temperature_c: event_data[:temperature_c],
            recorded_at: parse_timestamp(event_data[:recorded_at]),
            recorded_by: event_data[:recorded_by]
          )
          event.save!
          processed += 1
        rescue => e
          errors << "Event #{event_data[:event_type]}: #{e.message}"
        end
      end

      CacheService.invalidate_truck(truck_id) if processed > 0

      { processed: processed, errors: errors }
    end

    # Batch warehouse readings
    def process_warehouse_readings_batch(warehouse_id, readings)
      return { processed: 0, errors: [] } if readings.blank?

      warehouse = Warehouse.find_by(id: warehouse_id)
      return { processed: 0, errors: ['Warehouse not found'] } unless warehouse

      records = readings.map do |reading|
        {
          warehouse_id: warehouse_id,
          storage_zone_id: reading[:storage_zone_id] || reading[:zone_id],
          temperature: reading[:temperature_c] || reading[:temperature],
          humidity: reading[:humidity],
          recorded_at: parse_timestamp(reading[:recorded_at] || reading[:timestamp]),
          sensor_id: reading[:sensor_id],
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      begin
        WarehouseReading.insert_all(records)
        CacheService.invalidate_warehouse(warehouse_id)
        { processed: records.size, errors: [] }
      rescue => e
        { processed: 0, errors: [e.message] }
      end
    end

    # Bulk AI analysis
    def batch_ai_analysis(entity_type, entity_ids, analysis_type)
      return { processed: 0, errors: [] } if entity_ids.blank?

      processed = 0
      errors = []
      results = []

      entity_class = entity_type.to_s.classify.constantize
      entities = entity_class.where(id: entity_ids)

      entities.find_each do |entity|
        begin
          result = case analysis_type.to_s
                   when 'risk_assessment'
                     AiIntegrationService.assess_risk(entity)
                   when 'anomaly_detection'
                     AiIntegrationService.detect_anomalies(entity) if entity.respond_to?(:telemetry_readings)
                   when 'compliance_review'
                     AiIntegrationService.review_compliance(entity) if entity.is_a?(Route)
                   else
                     { error: "Unknown analysis type: #{analysis_type}" }
                   end

          if result&.dig(:success)
            processed += 1
            results << { entity_id: entity.id, request_id: result[:request]&.id }
          elsif result&.dig(:error)
            errors << "#{entity.id}: #{result[:error]}"
          end
        rescue => e
          errors << "#{entity.id}: #{e.message}"
        end
      end

      { processed: processed, errors: errors, results: results }
    end

    # Data export batch processing
    def export_telemetry(truck_id, start_date:, end_date:, format: :csv)
      truck = Truck.find(truck_id)
      readings = truck.telemetry_readings
                      .where(recorded_at: start_date..end_date)
                      .order(recorded_at: :asc)

      case format.to_sym
      when :csv
        export_to_csv(readings, %w[recorded_at temperature_c humidity latitude longitude speed_kph])
      when :json
        readings.as_json(only: %w[recorded_at temperature_c humidity latitude longitude speed_kph])
      else
        raise ArgumentError, "Unknown format: #{format}"
      end
    end

    # Cleanup old data
    def cleanup_old_telemetry(days_to_keep: 90)
      cutoff = days_to_keep.days.ago
      deleted = TelemetryReading.where('recorded_at < ?', cutoff).delete_all
      { deleted: deleted, cutoff_date: cutoff.to_date }
    end

    def cleanup_old_monitoring(days_to_keep: 90)
      cutoff = days_to_keep.days.ago
      deleted = Monitoring.where('recorded_at < ?', cutoff).delete_all
      { deleted: deleted, cutoff_date: cutoff.to_date }
    end

    def cleanup_old_audit_logs(days_to_keep: 365)
      cutoff = days_to_keep.days.ago
      deleted = AuditLog.where('created_at < ?', cutoff).delete_all
      { deleted: deleted, cutoff_date: cutoff.to_date }
    end

    def cleanup_old_ai_requests(days_to_keep: 30)
      cutoff = days_to_keep.days.ago
      deleted = AiRequest.where('created_at < ?', cutoff).delete_all
      { deleted: deleted, cutoff_date: cutoff.to_date }
    end

    private

    def parse_timestamp(value)
      return Time.current if value.blank?
      return value if value.is_a?(Time) || value.is_a?(DateTime)
      Time.zone.parse(value.to_s)
    rescue
      Time.current
    end

    def trigger_temperature_alert(truck, temperature)
      # Broadcast via ActionCable
      ActionCable.server.broadcast(
        'alerts_channel',
        {
          type: 'temperature_excursion',
          truck_id: truck.id,
          truck_name: truck.name,
          temperature: temperature,
          min_temp: truck.min_temp,
          max_temp: truck.max_temp,
          timestamp: Time.current.iso8601
        }
      )
    rescue => e
      Rails.logger.error("Alert broadcast failed: #{e.message}")
    end

    def export_to_csv(records, columns)
      require 'csv'
      CSV.generate(headers: true) do |csv|
        csv << columns
        records.find_each do |record|
          csv << columns.map { |col| record.send(col) }
        end
      end
    end
  end
end
