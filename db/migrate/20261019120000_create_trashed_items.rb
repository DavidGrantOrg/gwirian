class CreateTrashedItems < ActiveRecord::Migration[8.1]
  def change
    create_table :trashed_items do |t|
      t.references :project, null: false, foreign_key: true, index: false
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
end
