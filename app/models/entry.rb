class Entry < ApplicationRecord
  has_one :pin, dependent: :destroy
  has_one_attached :icon_image

  validates :watering_frequency, numericality: { greater_than: 0, allow_nil: true }

  ICON_EMOJIS = %w[🌱 🌿 🍀 🌵 🌴 🌳 🌲 🪴 🌻 🌺 🌸 🌷 🌹 🪻 🍃 🌾 🎋 🎍 🍂 🍁].freeze

  # Entries that need watering soonest first, then entries without a schedule last
  scope :by_watering_urgency, -> {
    order(
      Arel.sql(<<~SQL.squish)
        CASE
          WHEN watering_frequency IS NULL THEN 1
          ELSE 0
        END ASC,
        CASE
          WHEN watering_frequency IS NOT NULL
          THEN COALESCE(last_watered_at, created_at) + (watering_frequency || ' days')::interval
          ELSE NULL
        END ASC NULLS LAST
      SQL
    )
  }

  def display_icon
    icon.presence || "🌱"
  end

  def needs_watering?
    return false unless watering_frequency.present?

    watered = last_watered_at || created_at
    watered + watering_frequency.days <= Time.current
  end

  # How desperately the plant needs water, as a fraction of its watering
  # interval elapsed past the due date: 0.0 at due, 1.0 once a full extra
  # interval has passed. nil when unscheduled, negative when not yet due.
  def watering_overdue_ratio
    return nil unless watering_frequency.present?

    interval = watering_frequency.days
    watered = last_watered_at || created_at
    (Time.current - (watered + interval)) / interval
  end

  # nil when watering is not (yet) needed, otherwise :due -> :thirsty -> :parched.
  def watering_urgency
    ratio = watering_overdue_ratio
    return nil if ratio.nil? || ratio.negative?

    if ratio >= 1.0
      :parched
    elsif ratio >= 0.5
      :thirsty
    else
      :due
    end
  end

  def next_watering_at
    return nil unless watering_frequency.present?

    watered = last_watered_at || created_at
    watered + watering_frequency.days
  end

  def water!
    update!(last_watered_at: Time.current)
  end
end
