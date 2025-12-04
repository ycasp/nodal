require "application_system_test_case"

class FlashTest < ApplicationSystemTestCase
  test "visiting the index shows flash messages" do
    visit root_url
  
    assert_selector ".alert.alert-info", text: "This is a test notice"
    assert_selector ".alert.alert-warning", text: "This is a test alert"
    
    # Sleep to let the user see the browser
    sleep 5
  end
end
