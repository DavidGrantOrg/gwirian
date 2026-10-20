require "rails_helper"

RSpec.describe Trash do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:feature) { create(:feature, project: project, title: "Suggested orders", tag_list: "P1, ordering") }

  def tagged_runs_feature
    [ "Order a full case", "Order singles" ].each do |title|
      scenario = create(:scenario, feature: feature, title: title, given: "a store", when: "it orders", then: "it gets a case")
      scenario.steps.create!(action: "Given a store")
      scenario.steps.create!(action: "When it orders")
      create(:scenario_execution, scenario: scenario, user: user, status: "passed", notes: "fine", tag_list: "nightly, e2e")
    end
    feature
  end

  def rows_of(feature)
    scenarios = Scenario.where(feature_id: feature.id).order(:id)
    {
      features: Feature.where(id: feature.id).map(&:attributes),
      scenarios: scenarios.map(&:attributes),
      steps: Step.where(scenario_id: scenarios.ids).order(:id).map(&:attributes),
      runs: ScenarioExecution.where(scenario_id: scenarios.ids).order(:id).map(&:attributes),
      feature_tags: Feature.find_by(id: feature.id)&.tag_list&.sort,
      run_tags: ScenarioExecution.where(scenario_id: scenarios.ids).order(:id).map { |run| run.tag_list.sort }
    }
  end

  def positions(feature)
    Scenario.where(feature_id: feature.id).order(:position, :id).pluck(:id, :position)
  end

  describe ".move!" do
    it "removes the feature with everything its delete destroys, and keeps a trash item naming it" do
      tagged_runs_feature

      item = Trash.move!(feature, by: user)

      expect(Feature.exists?(feature.id)).to be(false)
      expect(Scenario.where(feature_id: feature.id)).to be_empty
      expect([ item.event, item.item_type, item.item_id, item.title, item.project, item.trashed_by, item.feature_id ])
        .to eq([ "destroy", "Feature", feature.id, "Suggested orders", project, user, nil ])
    end

    it "names a scenario's feature on its trash item" do
      scenario = create(:scenario, feature: feature)

      item = Trash.move!(scenario, by: user)

      expect([ item.item_type, item.item_id, item.feature_id ]).to eq([ "Scenario", scenario.id, feature.id ])
    end

    it "snapshots an edit committed after the record was looked up" do
      stale = Feature.find(feature.id)
      Feature.find(feature.id).update!(title: "Suggested orders, renamed")

      item = Trash.move!(stale, by: user)

      expect(item.title).to eq("Suggested orders, renamed")
      expect(item.payload["features"].map { |row| row["title"] }).to eq([ "Suggested orders, renamed" ])
    end

    it "refuses a second, stale delete of the same feature, leaving one trash item" do
      first_lookup = Feature.find(feature.id)
      second_lookup = Feature.find(feature.id)
      Trash.move!(first_lookup, by: user)

      expect { Trash.move!(second_lookup, by: user) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(TrashedItem.count).to eq(1)
    end

    it "keeps the feature and writes no trash item when the delete fails" do
      allow_any_instance_of(Feature).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

      expect { Trash.move!(feature, by: user) }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(Feature.exists?(feature.id)).to be(true)
      expect(TrashedItem.count).to eq(0)
    end
  end

  describe ".restore!" do
    it "brings a feature back row for row, to the microsecond, with its tags and its runs' tags" do
      tagged_runs_feature
      before = rows_of(feature)

      Trash.restore!(Trash.move!(feature, by: user))

      expect(rows_of(feature)).to eq(before)
      expect(before[:runs].map { |run| run["executed_at"].usec }).to all(be_positive)
    end

    it "removes the item from the Trash" do
      item = Trash.move!(feature, by: user)

      Trash.restore!(item)

      expect(TrashedItem.exists?(item.id)).to be(false)
    end

    it "says what came back" do
      restored = Trash.restore!(Trash.move!(feature, by: user))

      expect([ restored.item_type, restored.item_id, restored.number, restored.project_id, restored.feature_id, restored.message ])
        .to eq([ "Feature", feature.id, "F#{feature.id}", project.id, feature.id, "Restored F#{feature.id}." ])
    end

    it "brings a feature back unfiled when its folder has gone" do
      folder = create(:folder, project: project)
      feature.update!(folder: folder)
      item = Trash.move!(feature, by: user)
      folder.destroy!

      restored = Trash.restore!(item)

      expect(Feature.find(feature.id).folder_id).to be_nil
      expect(restored.message).to eq("Restored F#{feature.id} unfiled; its folder no longer exists.")
    end

    it "restores a row that today's validations would refuse" do
      scenario = create(:scenario, feature: feature)
      scenario.update_column(:title, "x" * 300)

      Trash.restore!(Trash.move!(scenario, by: user))

      expect(Scenario.find(scenario.id).title).to eq("x" * 300)
    end

    describe "positions" do
      let!(:scenarios) { Array.new(4) { |i| create(:scenario, feature: feature, title: "Scenario #{i + 1}") } }

      it "keeps a whole feature's stored positions as they were, nil and duplicates included" do
        scenarios[0].update_column(:position, nil)
        scenarios[2].update_column(:position, 2)
        before = positions(feature)

        Trash.restore!(Trash.move!(feature, by: user))

        expect(positions(feature)).to eq(before)
      end

      it "puts a scenario back at its old position" do
        Trash.restore!(Trash.move!(scenarios[1], by: user))

        expect(positions(feature)).to eq(scenarios.map(&:id).zip([ 1, 2, 3, 4 ]))
      end

      it "puts a scenario last when its old position is beyond the list" do
        last = Trash.move!(scenarios[3], by: user)
        Trash.move!(scenarios[2], by: user)
        Trash.move!(scenarios[1], by: user)

        Trash.restore!(last)

        expect(positions(feature)).to eq([ [ scenarios[0].id, 1 ], [ scenarios[3].id, 2 ] ])
      end

      it "keeps a scenario's nil position" do
        scenarios[1].update_column(:position, nil)

        Trash.restore!(Trash.move!(scenarios[1], by: user))

        expect(Scenario.find(scenarios[1].id).position).to be_nil
      end

      it "returns the original order when two scenarios come back in the reverse of the order they left" do
        second = Trash.move!(scenarios[1], by: user)
        third = Trash.move!(scenarios[2], by: user)

        Trash.restore!(third)
        Trash.restore!(second)

        expect(positions(feature)).to eq(scenarios.map(&:id).zip([ 1, 2, 3, 4 ]))
      end

      it "keeps the list whole when two scenarios come back in the order they left" do
        second = Trash.move!(scenarios[1], by: user)
        third = Trash.move!(scenarios[2], by: user)

        Trash.restore!(second)
        Trash.restore!(third)

        expect(positions(feature)).to eq([ scenarios[0], scenarios[2], scenarios[1], scenarios[3] ].map(&:id).zip([ 1, 2, 3, 4 ]))
      end
    end

    it "brings a scenario's steps back in their order" do
      scenario = create(:scenario, feature: feature)
      steps = [ "Given a store", "When it orders", "Then it gets a case" ].map { |action| scenario.steps.create!(action: action) }

      Trash.restore!(Trash.move!(scenario, by: user))

      expect(Scenario.find(scenario.id).steps.map(&:id)).to eq(steps.map(&:id))
    end

    it "refuses a scenario whose feature is in the Trash, naming the call that restores the feature" do
      scenario = create(:scenario, feature: feature)
      scenario_item = Trash.move!(scenario, by: user)
      feature_item = Trash.move!(feature, by: user)

      expect { Trash.restore!(scenario_item) }.to raise_error(Trash::Refused) { |error|
        expect([ error.code, error.message ]).to eq([
          "trash.feature_in_trash",
          "S#{scenario.id}'s feature F#{feature.id} is in the Trash; restore it first: restore_trashed_item(trashed_item_id: #{feature_item.id})"
        ])
      }
      expect(TrashedItem.exists?(scenario_item.id)).to be(true)
    end

    it "refuses a scenario whose feature no longer exists" do
      scenario = create(:scenario, feature: feature)
      item = Trash.move!(scenario, by: user)
      feature.destroy!

      expect { Trash.restore!(item) }.to raise_error(Trash::Refused) { |error|
        expect([ error.code, error.message ]).to eq([
          "trash.feature_gone",
          "S#{scenario.id}'s feature F#{feature.id} no longer exists; download its snapshot from the Trash."
        ])
      }
    end

    it "refuses a snapshot taken under a schema older than this version restores" do
      item = Trash.move!(feature, by: user)
      item.update!(payload: item.payload.merge("schema_version" => Trash::RESTORABLE_SINCE - 1))

      expect { Trash.restore!(item) }.to raise_error(Trash::Refused) { |error|
        expect([ error.code, error.message ]).to eq([
          "trash.schema_incompatible",
          "F#{feature.id} was trashed under schema version #{Trash::RESTORABLE_SINCE - 1}, older than #{Trash::RESTORABLE_SINCE}, " \
            "the oldest this version restores; download its snapshot from the Trash."
        ])
      }
      expect(Feature.exists?(feature.id)).to be(false)
      expect(TrashedItem.exists?(item.id)).to be(true)
    end

    it "says an item no longer in the Trash is gone" do
      item = Trash.move!(feature, by: user)
      Trash.restore!(item)

      expect { Trash.restore!(item) }.to raise_error(Trash::Gone, "That item is no longer in the Trash.") { |error|
        expect(error.code).to eq("trash.gone")
      }
    end

    it "says the item is gone when an overlapping restore took it first" do
      item = Trash.move!(feature, by: user)
      stale = TrashedItem.find(item.id)
      Trash.restore!(item)
      allow(TrashedItem).to receive(:find_by).and_return(stale)

      expect { Trash.restore!(stale) }.to raise_error(Trash::Gone)
    end

    it "lets any other clash on restore through, and keeps the item" do
      scenario = create(:scenario, feature: feature)
      step = scenario.steps.create!(action: "Given a store")
      item = Trash.move!(scenario, by: user)
      Step.insert({ id: step.id, scenario_id: create(:scenario, feature: feature).id, action: "squatter", position: 1, created_at: Time.current, updated_at: Time.current })

      expect { Trash.restore!(item) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(TrashedItem.exists?(item.id)).to be(true)
      expect(Scenario.exists?(scenario.id)).to be(false)
    end
  end

  describe ".purge!" do
    it "deletes a feature's item with the trashed scenarios whose feature it was" do
      scenario_item = Trash.move!(create(:scenario, feature: feature), by: user)
      other_item = Trash.move!(create(:scenario, feature: create(:feature, project: project)), by: user)

      Trash.purge!(Trash.move!(feature, by: user))

      expect(TrashedItem.where(id: [ scenario_item.id, other_item.id ]).ids).to eq([ other_item.id ])
    end

    it "deletes only a scenario's item while its feature is live" do
      scenario = create(:scenario, feature: feature)
      keep = create(:scenario, feature: feature)
      item = Trash.move!(scenario, by: user)
      before = rows_of(feature)

      Trash.purge!(item)

      expect(TrashedItem.exists?(item.id)).to be(false)
      expect(rows_of(feature)).to eq(before)
      expect(Scenario.exists?(keep.id)).to be(true)
    end

    it "says an item no longer in the Trash is gone" do
      item = Trash.move!(feature, by: user)
      Trash.purge!(item)

      expect { Trash.purge!(item) }.to raise_error(Trash::Gone)
    end
  end

  it "lets a project with items in the Trash be deleted" do
    Trash.move!(feature, by: user)

    project.destroy!

    expect(TrashedItem.count).to eq(0)
  end

  it "lets a workspace with items in the Trash be deleted" do
    Trash.move!(feature, by: user)

    project.workspace.destroy!

    expect(TrashedItem.count).to eq(0)
  end

  it "keeps the trash item when the user who trashed it goes" do
    item = Trash.move!(feature, by: create(:user))

    item.trashed_by.destroy!

    expect(item.reload.trashed_by).to be_nil
  end

  # A restored row keeps its id, so a table that reused a deleted id would hand it to a new row first.
  it "never reuses a deleted id in the tables a restore writes to" do
    scenario = create(:scenario, feature: feature)
    rows = {
      Folder => -> { create(:folder, project: project) },
      Feature => -> { create(:feature, project: project) },
      Scenario => -> { create(:scenario, feature: feature) },
      Step => -> { scenario.steps.create!(action: "Given a store") },
      ScenarioExecution => -> { create(:scenario_execution, scenario: scenario, user: user) }
    }

    rows.each do |model, build|
      newest = build.call
      model.where(id: newest.id).delete_all

      expect(build.call.id).to be > newest.id, "#{model.table_name} reused id #{newest.id}"
    end
  end

  # Restore writes a snapshot's columns back as they were. A migration that changes one of these tables
  # must raise Trash::RESTORABLE_SINCE, or teach restore to convert older snapshots and add a fixture
  # for them under spec/fixtures/trash/.
  it "pins the columns a snapshot holds" do
    expect({
      features: Feature.column_names,
      scenarios: Scenario.column_names,
      steps: Step.column_names,
      scenario_executions: ScenarioExecution.column_names,
      taggings: ActsAsTaggableOn::Tagging.column_names
    }).to eq({
      features: %w[id title description created_at updated_at project_id background folder_id],
      scenarios: %w[id feature_id title given when then created_at updated_at position backlog],
      steps: %w[id scenario_id action created_at updated_at position],
      scenario_executions: %w[id scenario_id user_id status notes executed_at created_at updated_at],
      taggings: %w[id tag_id taggable_type taggable_id tagger_type tagger_id context created_at tenant]
    })
  end

  it "restores a snapshot written by the oldest version it accepts" do
    payload = JSON.parse(Rails.root.join("spec/fixtures/trash/feature.json").read)
    expect(payload["schema_version"]).to eq(Trash::RESTORABLE_SINCE)
    item = TrashedItem.create!(project: create(:project, id: 900_001), event: "destroy", item_type: "Feature", item_id: 900_001,
      title: "Suggested orders", payload: payload)
    create(:user, id: 900_001)

    Trash.restore!(item)

    restored = Feature.find(900_001)
    expect([ restored.title, restored.tag_list, restored.scenarios.map(&:title), restored.scenarios.first.steps.map(&:action) ])
      .to eq([ "Suggested orders", [ "P1" ], [ "Order a full case" ], [ "Given a store" ] ])
    expect(restored.scenarios.first.scenario_executions.map { |run| [ run.status, run.tag_list ] }).to eq([ [ "passed", [ "nightly" ] ] ])
  end
end
