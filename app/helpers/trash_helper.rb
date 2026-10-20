module TrashHelper
  # A feature's scenarios that were trashed on their own go with it, so they count too.
  def delete_forever_message(item, trashed_scenarios: 0)
    count = item.item_type == "Feature" ? item.snapshot_scenario_ids.size + trashed_scenarios : 0
    subject = count.zero? ? item.number : "#{item.number} and its #{pluralize(count, 'scenario')}"
    "Delete #{subject} forever? This cannot be undone."
  end
end
