class CreateFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :folders do |t|
      t.references :project, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :folders }
      t.string :name, null: false
      t.timestamps
    end

    # A plain (project_id, parent_id, name) index would let two top-level folders share a
    # name, because every NULL parent_id counts as different.
    add_index :folders, "project_id, COALESCE(parent_id, 0), lower(name)",
      unique: true, name: "index_folders_on_project_parent_and_name"

    add_reference :features, :folder, foreign_key: true
  end
end
