# frozen_string_literal: true

# Search with SQL when SEARCH_BACKEND=database: every word of the query must appear,
# in any case, somewhere in one of the given columns or the record's tags.
module DbSearchable
  extend ActiveSupport::Concern

  class_methods do
    def db_search(query, columns, tags: false)
      query.to_s.split.reduce(all) do |relation, word|
        pattern = "%#{sanitize_sql_like(word)}%"
        matches = columns.map { |column| column.matches(pattern, "\\") }
        matches << arel_table[:id].in(tagged_ids_matching(pattern).arel) if tags
        relation.where(matches.reduce(:or))
      end
    end

    private

    def tagged_ids_matching(pattern)
      ActsAsTaggableOn::Tagging.joins(:tag)
        .where(taggable_type: name, context: "tags")
        .where(ActsAsTaggableOn::Tag.arel_table[:name].matches(pattern, "\\"))
        .select(:taggable_id)
    end
  end
end
