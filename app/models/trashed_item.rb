class TrashedItem < ApplicationRecord
  belongs_to :project
  belongs_to :trashed_by, class_name: "User", optional: true

  # Every column but the payload, with the ids of the scenarios inside a feature's snapshot;
  # a scenario's snapshot holds only itself, so it lists none.
  scope :listing, -> {
    select(column_names.without("payload").map { |column| arel_table[column] },
      Arel.sql("CASE WHEN trashed_items.item_type = 'Feature' THEN (SELECT json_group_array(json_extract(value, '$.id')) " \
        "FROM json_each(trashed_items.payload, '$.scenarios')) ELSE '[]' END AS snapshot_scenario_ids"))
  }

  def number
    "#{item_type.first}#{item_id}"
  end

  # From the listing scope's column, or else the payload; with neither loaded, payload raises.
  def snapshot_scenario_ids
    return JSON.parse(self[:snapshot_scenario_ids]) if has_attribute?(:snapshot_scenario_ids)

    item_type == "Feature" ? payload.fetch("scenarios").map { |row| row["id"] } : []
  end
end
