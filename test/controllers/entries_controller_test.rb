require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  # --- Unauthenticated access is gated ---

  test "unauthenticated GET root redirects to sign in" do
    get root_url
    assert_redirected_to new_user_session_path
  end

  test "unauthenticated POST create redirects to sign in and creates nothing" do
    assert_no_difference "Entry.count" do
      post entries_url, params: { entry: { name: "Intruder Fern" } }
    end
    assert_redirected_to new_user_session_path
  end

  test "unauthenticated POST water redirects to sign in and does not water the entry" do
    entry = entries(:one)
    assert_nil entry.last_watered_at

    post water_entry_url(entry)

    assert_redirected_to new_user_session_path
    assert_nil entry.reload.last_watered_at
  end

  # --- Authenticated access is allowed ---

  test "signed-in GET root succeeds" do
    sign_in users(:one)
    get root_url
    assert_response :success
  end

  test "signed-in POST create adds an entry and redirects to root" do
    sign_in users(:one)
    assert_difference "Entry.count", 1 do
      post entries_url, params: { entry: { name: "Monstera" } }
    end
    assert_redirected_to root_url
  end

  test "signed-in POST water stamps last_watered_at" do
    sign_in users(:one)
    entry = entries(:one)
    assert_nil entry.last_watered_at

    post water_entry_url(entry)

    assert_redirected_to root_url
    assert_not_nil entry.reload.last_watered_at
  end

  # --- Real login flow through the Devise endpoint ---

  test "logging in via user_session_path with fixture credentials grants access" do
    post user_session_path, params: {
      user: { email: "one@example.com", password: "password123" }
    }
    assert_response :redirect
    follow_redirect!

    get root_url
    assert_response :success
  end

  test "logging in with a wrong password does not grant access" do
    post user_session_path, params: {
      user: { email: "one@example.com", password: "wrong-password" }
    }

    get root_url
    assert_redirected_to new_user_session_path
  end
end
