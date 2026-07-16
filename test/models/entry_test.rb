require "test_helper"

class EntryTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 6, 15, 12, 0, 0)

  # Builds an unsaved entry; the watering methods only read attributes,
  # so persistence (and fixtures) are unnecessary.
  def entry(watering_frequency: nil, last_watered_at: nil, created_at: NOW - 30.days)
    Entry.new(
      name: "Test plant",
      watering_frequency: watering_frequency,
      last_watered_at: last_watered_at,
      created_at: created_at
    )
  end

  test "watering_overdue_ratio is nil without a watering_frequency" do
    travel_to NOW do
      assert_nil entry(last_watered_at: NOW - 10.days).watering_overdue_ratio
    end
  end

  test "watering_urgency is nil without a watering_frequency" do
    travel_to NOW do
      assert_nil entry(last_watered_at: NOW - 10.days).watering_urgency
    end
  end

  test "watering_overdue_ratio is negative before the due date" do
    travel_to NOW do
      ratio = entry(watering_frequency: 4, last_watered_at: NOW - 2.days).watering_overdue_ratio

      assert_in_delta(-0.5, ratio, 0.001)
    end
  end

  test "watering_urgency is nil before the due date" do
    travel_to NOW do
      assert_nil entry(watering_frequency: 4, last_watered_at: NOW - 2.days).watering_urgency
    end
  end

  test "ratio is 0.0 and urgency is :due exactly at the due date" do
    travel_to NOW do
      plant = entry(watering_frequency: 4, last_watered_at: NOW - 4.days)

      assert_in_delta 0.0, plant.watering_overdue_ratio, 0.001
      assert_equal :due, plant.watering_urgency
    end
  end

  test "urgency is :due just past the due date (ratio below 0.5)" do
    travel_to NOW do
      plant = entry(watering_frequency: 4, last_watered_at: NOW - 5.days)

      assert_in_delta 0.25, plant.watering_overdue_ratio, 0.001
      assert_equal :due, plant.watering_urgency
    end
  end

  test "urgency is :thirsty at ratio 0.5" do
    travel_to NOW do
      # frequency 4 days, watered 6 days ago -> (6 - 4) / 4 = 0.5
      plant = entry(watering_frequency: 4, last_watered_at: NOW - 6.days)

      assert_in_delta 0.5, plant.watering_overdue_ratio, 0.001
      assert_equal :thirsty, plant.watering_urgency
    end
  end

  test "urgency is :thirsty just below ratio 1.0" do
    travel_to NOW do
      plant = entry(watering_frequency: 4, last_watered_at: NOW - 7.days)

      assert_in_delta 0.75, plant.watering_overdue_ratio, 0.001
      assert_equal :thirsty, plant.watering_urgency
    end
  end

  test "urgency is :parched at exactly one full extra interval (ratio 1.0)" do
    travel_to NOW do
      plant = entry(watering_frequency: 4, last_watered_at: NOW - 8.days)

      assert_in_delta 1.0, plant.watering_overdue_ratio, 0.001
      assert_equal :parched, plant.watering_urgency
    end
  end

  test "urgency is :parched when watered two full intervals ago" do
    travel_to NOW do
      plant = entry(watering_frequency: 3, last_watered_at: NOW - 9.days)

      assert_in_delta 2.0, plant.watering_overdue_ratio, 0.001
      assert_equal :parched, plant.watering_urgency
    end
  end

  test "falls back to created_at when last_watered_at is nil" do
    travel_to NOW do
      # never watered, created 6 days ago, frequency 4 -> ratio 0.5 -> :thirsty
      plant = entry(watering_frequency: 4, created_at: NOW - 6.days)

      assert_in_delta 0.5, plant.watering_overdue_ratio, 0.001
      assert_equal :thirsty, plant.watering_urgency
    end
  end
end
