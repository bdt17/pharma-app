require "test_helper"

class Api::V1::MonitoringsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get api_v1_monitorings_create_url
    assert_response :success
  end
end
