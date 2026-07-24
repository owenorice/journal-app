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

  # --- Lightbox trigger contract on the index ---

  test "entry with an attached icon image renders a lightbox trigger button" do
    sign_in users(:one)
    entry = entries(:one)
    entry.update!(name: "Fiddle Leaf Fig")
    # The view only builds a URL for the blob (no variant processing), so the
    # payload just needs to be attachable bytes with an image content type.
    entry.icon_image.attach(
      io: StringIO.new("\x89PNG\r\n\x1a\ntiny-test-image".b),
      filename: "icon.png",
      content_type: "image/png"
    )

    get root_url
    assert_response :success

    card = "#entry-card-#{entry.id}"
    assert_select "#{card} button.entry-row__thumb.entry-row__thumb--clickable", count: 1
    assert_select "#{card} button.entry-row__thumb--clickable[data-action*=?]", "lightbox#open"
    assert_select "#{card} button.entry-row__thumb--clickable[data-lightbox-src-param*=?]",
                  "/rails/active_storage/blobs/"
    assert_select "#{card} button.entry-row__thumb--clickable[data-lightbox-caption-param=?]",
                  "Fiddle Leaf Fig"
  end

  test "entry without an icon image renders a plain thumb and no lightbox trigger" do
    sign_in users(:one)
    entry = entries(:two)

    get root_url
    assert_response :success

    assert_select "#entry-card-#{entry.id}" do
      assert_select "div.entry-row__thumb", text: entry.display_icon, count: 1
      assert_select "button.entry-row__thumb--clickable", count: 0
      assert_select "[data-action*=?]", "lightbox#open", count: 0
    end
  end

  test "layout renders the lightbox overlay wired to the lightbox controller" do
    sign_in users(:one)
    get root_url
    assert_response :success

    assert_select "body[data-controller=?]", "lightbox"
    assert_select ".lightbox[data-lightbox-target=?]", "overlay", count: 1
  end

  # --- Name validation through the controller ---

  test "signed-in POST create with a blank name creates nothing and responds 422" do
    sign_in users(:one)

    assert_no_difference "Entry.count" do
      post entries_url, params: { entry: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "signed-in PATCH update with a blank name keeps the stored name and redirects with an alert" do
    sign_in users(:one)
    entry = entries(:one)
    original_name = entry.name

    patch entry_url(entry), params: { entry: { name: "" } }

    assert_redirected_to root_url
    assert_includes flash[:alert], "Name can't be blank"
    assert_equal original_name, entry.reload.name
  end

  # --- last_modified_by stamping ---

  test "signed-in POST create stamps last_modified_by with the current user" do
    sign_in users(:one)

    post entries_url, params: { entry: { name: "Stamped Fern" } }

    assert_equal users(:one), Entry.find_by!(name: "Stamped Fern").last_modified_by
  end

  test "signed-in PATCH update stamps last_modified_by with the current user" do
    sign_in users(:two)
    entry = entries(:one)
    assert_nil entry.last_modified_by

    patch entry_url(entry), params: { entry: { name: "Renamed Fern" } }

    assert_redirected_to root_url
    entry.reload
    assert_equal "Renamed Fern", entry.name
    assert_equal users(:two), entry.last_modified_by
  end

  test "signed-in POST water stamps last_modified_by and last_watered_at" do
    sign_in users(:two)
    entry = entries(:one)
    assert_nil entry.last_modified_by
    assert_nil entry.last_watered_at

    post water_entry_url(entry)

    entry.reload
    assert_not_nil entry.last_watered_at
    assert_equal users(:two), entry.last_modified_by
  end

  # --- "Last modified by" marker on the index ---

  test "index shows the modified-by marker only inside the edit panel of a stamped entry" do
    stamped = entries(:one)
    stamped.update!(last_modified_by: users(:one))
    sign_in users(:one)

    get root_url

    assert_response :success
    assert_select "#entry-panel-#{stamped.id} .entry-expand__modified-by",
                  text: /Last modified by one@example\.com/
    # The list row for the same entry carries no marker.
    assert_select "#entry-card-#{stamped.id} .entry-expand__modified-by", count: 0
    assert_select "#entry-card-#{stamped.id}" do |cards|
      assert_no_match(/Last modified by/, cards.first.text)
    end
    # Only the stamped entry renders a marker anywhere on the page
    # (unstamped entries and the new-entry panel render none).
    assert_select ".entry-expand__modified-by", count: 1
  end

  test "index renders no modified-by marker for an entry whose last_modified_by is nil" do
    unstamped = entries(:two)
    assert_nil unstamped.last_modified_by
    sign_in users(:one)

    get root_url

    assert_response :success
    assert_select "#entry-panel-#{unstamped.id} .entry-expand__modified-by", count: 0
    assert_select ".entry-expand__modified-by", count: 0
  end
end
