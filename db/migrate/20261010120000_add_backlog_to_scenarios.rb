class AddBacklogToScenarios < ActiveRecord::Migration[8.1]
  def change
    add_column :scenarios, :backlog, :boolean, default: false, null: false
  end
end
