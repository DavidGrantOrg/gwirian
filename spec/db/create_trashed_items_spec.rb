require "rails_helper"
require Rails.root.join("db/migrate/20261019120000_create_trashed_items")

RSpec.describe CreateTrashedItems do
  # A trashed item's rows are already gone from their own tables, so dropping trashed_items loses them.
  it "refuses to roll back while the Trash holds items" do
    Trash.move!(create(:feature), by: create(:user))

    expect { ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:down) } }
      .to raise_error(ActiveRecord::IrreversibleMigration,
        /^Rolling back would delete the 1 item in the Trash for good; back up the database and empty the Trash first\.$/)
    expect(TrashedItem.count).to eq(1)
  end
end
