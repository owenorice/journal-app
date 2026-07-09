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

  def next_watering_at
    return nil unless watering_frequency.present?

    watered = last_watered_at || created_at
    watered + watering_frequency.days
  end

  def water!
    update!(last_watered_at: Time.current)
  end
end
