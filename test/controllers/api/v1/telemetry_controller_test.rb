require "test_helper"

class Api::V1::TelemetryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @truck = trucks(:one)
    @auth_header = { "Authorization" => 'Token token="dev-secret-token"' }
  end

  test "should create telemetry reading with valid data" do
    assert_difference("TelemetryReading.count") do
      post api_v1_truck_telemetry_index_url(@truck),
        params: {
          telemetry: {
            latitude: 42.3601,
            longitude: -71.0589,
            temperature_c: 5.5,
            humidity: 45.0,
            speed_kph: 60.0,
            recorded_at: Time.current.iso8601
          }
        },
        headers: @auth_header,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal @truck.id, json["truck_id"]
    assert_equal "5.5", json["temperature_c"].to_s
  end

  test "should reject telemetry without location or sensor data" do
    assert_no_difference("TelemetryReading.count") do
      post api_v1_truck_telemetry_index_url(@truck),
        params: {
          telemetry: {
            recorded_at: Time.current.iso8601
          }
        },
        headers: @auth_header,
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "should require authentication" do
    post api_v1_truck_telemetry_index_url(@truck),
      params: {
        telemetry: {
          temperature_c: 5.5,
          recorded_at: Time.current.iso8601
        }
      },
      as: :json

    assert_response :unauthorized
  end

  test "should get latest telemetry" do
    @truck.telemetry_readings.create!(
      temperature_c: 6.0,
      recorded_at: 1.minute.ago
    )

    get latest_api_v1_truck_telemetry_index_url(@truck),
      headers: @auth_header

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "6.0", json["temperature_c"].to_s
  end
end
