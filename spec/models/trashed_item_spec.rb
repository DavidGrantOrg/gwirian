require "rails_helper"

RSpec.describe TrashedItem do
  let(:user) { create(:user) }
  let(:feature) { create(:feature) }

  it "lists the scenarios in a feature's snapshot, and none for a scenario's" do
    scenarios = create_list(:scenario, 2, feature: feature)
    scenario_item = Trash.move!(scenarios.first, by: user)
    feature_item = Trash.move!(feature, by: user)

    listed = TrashedItem.listing.index_by(&:id)

    expect([ listed[feature_item.id].snapshot_scenario_ids, listed[scenario_item.id].snapshot_scenario_ids ]).to eq([ [ scenarios.second.id ], [] ])
  end

  # Without the listing scope the ids are not loaded, and an empty list would undercount Delete forever's confirm.
  it "refuses to list snapshot scenarios for an item not loaded through the listing scope" do
    item = Trash.move!(feature, by: user)

    expect { TrashedItem.find(item.id).snapshot_scenario_ids }.to raise_error(KeyError)
  end
end
