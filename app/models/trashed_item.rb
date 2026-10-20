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

  def snapshot_scenario_ids
    JSON.parse(attributes.fetch("snapshot_scenario_ids"))
  end
end
