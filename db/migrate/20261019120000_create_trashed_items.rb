class CreateTrashedItems < ActiveRecord::Migration[8.1]
  def up
    create_table :trashed_items do |t|
      # Cascades so a project delete that skips the model (older code after a rollback) still works.
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      # "destroy" for a delete; the column leaves room for edit history later.
      t.string :event, null: false
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.string :title
      # No foreign key: the feature a trashed scenario names may itself be in the Trash, or gone.
      t.integer :feature_id
      t.json :payload, null: false
      t.references :trashed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :trashed_items, [ :project_id, :created_at ]
    add_index :trashed_items, :feature_id
    add_index :trashed_items, [ :item_type, :item_id ], unique: true, where: "event = 'destroy'"
  end

  # A trashed item's rows are already gone from their own tables; this table is their only copy.
  def down
    count = select_value("SELECT COUNT(*) FROM trashed_items").to_i
    if count.positive?
      raise ActiveRecord::IrreversibleMigration,
        "Rolling back would delete the #{count} #{'item'.pluralize(count)} in the Trash for good; " \
        "back up the database and empty the Trash first."
    end

    drop_table :trashed_items
  end
end
