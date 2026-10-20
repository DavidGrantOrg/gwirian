# Deleting a feature or scenario moves it here: a JSON snapshot of every row its delete
# destroys, kept until it is restored or deleted forever. Model destroy stays a hard delete.
module Trash
  # The oldest schema version whose snapshots restore as they are. A migration that changes
  # features, scenarios, steps, scenario_executions or taggings raises it, or converts older
  # snapshots (spec/services/trash_spec.rb pins those tables' columns). A snapshot records the
  # newest applied version, which a merged upstream migration with an older timestamp does not
  # move: ship a fresh, empty migration with it and raise this to that one's version.
  #
  # A migration that rebuilds one of those tables or folders (SQLite's change_column,
  # change_column_null, foreign key changes) resets its AUTOINCREMENT counter, so a trashed
  # row's id can be handed out again. Restore trusts a feature or folder only if it is older
  # than the trash item, and refuses a restore whose ids are taken (trash.conflict).
  RESTORABLE_SINCE = 2026_10_19_120000

  class Refused < StandardError
    # next_call: the MCP call that clears the refusal, for callers that can make it.
    attr_reader :code, :next_call

    def initialize(message, code:, next_call: nil)
      super(message)
      @code = code
      @next_call = next_call
    end
  end

  class Gone < Refused
    def initialize
      super("That item is no longer in the Trash.", code: "trash.gone")
    end
  end

  Restored = Data.define(:item_type, :item_id, :project_id, :feature_id, :unfiled) do
    def number
      "#{item_type.first}#{item_id}"
    end

    def message
      unfiled ? "Restored #{number} unfiled; its folder no longer exists." : "Restored #{number}."
    end
  end

  class << self
    def move!(record, by:)
      TrashedItem.transaction do
        current = record.class.find(record.id)
        item = TrashedItem.create!(
          project_id: current.is_a?(Feature) ? current.project_id : current.feature.project_id,
          event: "destroy", item_type: current.class.name, item_id: current.id, title: current.title,
          feature_id: current.is_a?(Scenario) ? current.feature_id : nil,
          payload: snapshot(current), trashed_by: by
        )
        current.destroy!
        item
      end
    end

    # A run whose user has gone fails its foreign key, and the restore rolls back whole;
    # no path deletes a user today.
    def restore!(item)
      TrashedItem.transaction do
        current = TrashedItem.find_by(id: item.id) or raise Gone
        refuse_older_schema!(current)
        restored = current.item_type == "Feature" ? restore_feature(current) : restore_scenario(current)
        current.destroy!
        restored
      end
    rescue ActiveRecord::RecordNotUnique => e
      # An overlapping restore wrote the same ids and took the item first.
      raise Gone unless TrashedItem.exists?(item.id)

      Rails.logger.warn("Trash restore of #{item.number} (trashed item #{item.id}) clashed: #{e.class}: #{e.message}")
      raise Refused.new("#{item.number} cannot be restored: another row has taken one of its ids; " \
        "download its snapshot from the Trash.", code: "trash.conflict")
    end

    def purge!(item)
      TrashedItem.transaction do
        current = TrashedItem.find_by(id: item.id) or raise Gone
        if current.item_type == "Feature"
          # Its own scenarios were trashed before it; a later one belongs to a feature that took its id.
          TrashedItem.where(event: "destroy", item_type: "Scenario", feature_id: current.item_id, project_id: current.project_id,
            created_at: ..current.created_at).delete_all
        end
        current.destroy!
      end
    end

    private

    def snapshot(record)
      features = record.is_a?(Feature) ? [ record ] : []
      scenarios = record.is_a?(Feature) ? Scenario.where(feature_id: record.id).order(:position, :id).to_a : [ record ]
      steps = Step.where(scenario_id: scenarios.map(&:id)).order(:scenario_id, :position, :id).to_a
      runs = ScenarioExecution.where(scenario_id: scenarios.map(&:id)).order(:id).to_a
      taggings = ActsAsTaggableOn::Tagging.where(taggable_type: "Feature", taggable_id: features.map(&:id))
        .or(ActsAsTaggableOn::Tagging.where(taggable_type: "ScenarioExecution", taggable_id: runs.map(&:id)))
        .includes(:tag).order(:id)
      {
        "schema_version" => ActiveRecord::Base.connection_pool.migration_context.current_version,
        "features" => features.map(&:attributes_before_type_cast),
        "scenarios" => scenarios.map(&:attributes_before_type_cast),
        "steps" => steps.map(&:attributes_before_type_cast),
        "scenario_executions" => runs.map(&:attributes_before_type_cast),
        "taggings" => taggings.map { |tagging| tagging.attributes_before_type_cast.merge("tag_name" => tagging.tag.name) }
      }
    end

    def refuse_older_schema!(item)
      version = item.payload["schema_version"].to_i
      current = ActiveRecord::Base.connection_pool.migration_context.current_version
      if version < RESTORABLE_SINCE
        raise Refused.new("#{item.number} was trashed under schema version #{version}, older than #{RESTORABLE_SINCE}, " \
          "the oldest this version restores; download its snapshot from the Trash.", code: "trash.schema_incompatible")
      end
      return if version <= current

      raise Refused.new("#{item.number} was trashed under schema version #{version}, newer than this database's #{current}; " \
        "download its snapshot from the Trash.", code: "trash.schema_incompatible")
    end

    # Positions come back as stored, nil and duplicates included.
    def restore_feature(item)
      rows = item.payload
      feature = build(Feature, rows.fetch("features").first)
      unfiled = feature.folder_id.present? &&
        !Folder.where(id: feature.folder_id, project_id: item.project_id, created_at: ..item.created_at).exists?
      feature.folder_id = nil if unfiled
      Scenario.acts_as_list_no_update([ Step ]) do
        feature.save!(validate: false)
        in_position_order(rows.fetch("scenarios")).each { |attributes| build(Scenario, attributes).save!(validate: false) }
        restore_scenario_contents(rows)
      end
      Restored.new(item_type: "Feature", item_id: feature.id, project_id: item.project_id, feature_id: feature.id, unfiled: unfiled)
    end

    # Back at its old position, or last when the list has grown shorter than that.
    def restore_scenario(item)
      rows = item.payload
      unless Feature.where(id: item.feature_id, project_id: item.project_id, created_at: ..item.created_at).exists?
        refuse_missing_feature!(item)
      end
      scenario = build(Scenario, rows.fetch("scenarios").first)
      if scenario.position
        siblings = Scenario.where(feature_id: item.feature_id)
        scenario.position = [ scenario.position, siblings.maximum(:position).to_i + 1 ].min
        siblings.where(position: scenario.position..).update_all("position = position + 1")
      end
      Scenario.acts_as_list_no_update([ Step ]) do
        scenario.save!(validate: false)
        restore_scenario_contents(rows)
      end
      Restored.new(item_type: "Scenario", item_id: scenario.id, project_id: item.project_id, feature_id: item.feature_id, unfiled: false)
    end

    def refuse_missing_feature!(item)
      feature_item = TrashedItem.find_by(event: "destroy", item_type: "Feature", item_id: item.feature_id, project_id: item.project_id)
      if feature_item
        raise Refused.new("#{item.number}'s feature F#{item.feature_id} is in the Trash; restore F#{item.feature_id} first.",
          code: "trash.feature_in_trash", next_call: "restore_trashed_item(trashed_item_id: #{feature_item.id})")
      end

      raise Refused.new("#{item.number}'s feature F#{item.feature_id} no longer exists; download its snapshot from the Trash.",
        code: "trash.feature_gone")
    end

    def restore_scenario_contents(rows)
      in_position_order(rows.fetch("steps")).each { |attributes| build(Step, attributes).save!(validate: false) }
      rows.fetch("scenario_executions").each { |attributes| build(ScenarioExecution, attributes).save!(validate: false) }
      rows.fetch("taggings").each do |attributes|
        # An exact, binary name match: acts-as-taggable's lookups match by substring (LIKE) or through
        # LOWER, which SQLite applies to ASCII only, so "Été" would miss and leave the tagging no tag.
        name = attributes.fetch("tag_name")
        tag = ActsAsTaggableOn::Tag.find_or_create_by!(name: name)
        build(ActsAsTaggableOn::Tagging, attributes.except("tag_name").merge("tag_id" => tag.id)).save!(validate: false)
      end
    end

    def in_position_order(rows)
      rows.sort_by { |row| [ row["position"].nil? ? 1 : 0, row["position"].to_i, row["id"] ] }
    end

    # The snapshot holds raw stored values; reading them as a row from the database keeps
    # timestamps to the microsecond, and save keeps a timestamp it is given. Only columns are
    # copied: a virtual tag_list would cache an empty list and index the row without its tags.
    # Rows are saved unvalidated under their stored ids and foreign keys, which is safe only
    # because move! alone writes payloads; never feed it one a user supplied.
    def build(model, attributes)
      model.new(model.instantiate(attributes).attributes.slice(*model.column_names))
    end
  end
end
