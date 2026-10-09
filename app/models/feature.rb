class Feature < ApplicationRecord
  include Elasticsearch::Model
  include ElasticsearchIndexing
  include ElasticsearchQuerySanitizer
  include DbSearchable

  belongs_to :project
  # No folder means the feature is unfiled, at the top of the project.
  belongs_to :folder, optional: true
  has_many :scenarios, -> { order(:position) }, dependent: :destroy
  has_many :scenario_executions, through: :scenarios
  acts_as_taggable_on :tags

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validate :folder_in_same_project

  settings index: { number_of_shards: 1 } do
    mappings dynamic: "false" do
      indexes :title, type: "text", analyzer: "english"
      indexes :description, type: "text", analyzer: "english"
      indexes :tags, type: "text", analyzer: "standard" do
        indexes :keyword, type: "keyword"
      end
      indexes :project_id, type: "integer"
    end
  end

  def as_indexed_json(options = {})
    {
      title: title,
      description: description,
      tags: tag_list,
      project_id: project_id
    }
  end

  # Returns the Gherkin content for this feature (tags, Feature:, description, Background, scenarios).
  def to_gherkin
    lines = []
    lines << tag_list.map { |t| "@#{t}" }.join(" ") if tag_list.present?
    lines << "Feature: #{gherkin_escape_line(title)}"
    gherkin_escape_description(description).each { |line| lines << "  #{line}" } if description.present?
    lines << ""
    if background.present?
      lines << "  Background:"
      GherkinSteps.lines(background, "Given").each { |line| lines << (line.empty? ? "" : "    #{line}") }
      lines << ""
    end
    scenarios.each do |scenario|
      scenario.to_gherkin.split("\n").each { |sline| lines << (sline.empty? ? "" : "  #{sline}") }
      lines << ""
    end
    lines.pop if lines.last == ""
    lines.join("\n")
  end

  private

  def folder_in_same_project
    if folder_id && folder.nil?
      errors.add(:folder, "must exist")
    elsif folder && folder.project_id != project_id
      errors.add(:folder, "must be in the same project")
    end
  end

  def gherkin_escape_line(text)
    return "" if text.blank?
    text.to_s.strip.gsub(/\r\n|\r/, "\n")
  end

  def gherkin_escape_description(text)
    return [] if text.blank?
    text.to_s.gsub(/\r\n|\r/, "\n").strip.split("\n").map(&:strip).reject(&:blank?)
  end

  public

  def self.search_by_project(query, project_id, limit: 100)
    unless Gwirian.elasticsearch?
      return where(project_id: project_id)
        .db_search(query, [ arel_table[:title], arel_table[:description] ], tags: true)
        .order(:title)
        .limit([ limit, 1000 ].min)
    end

    sanitized_query = sanitize_elasticsearch_query(query)
    search({
      size: [ limit, 1000 ].min, # Cap at 1000 to prevent DoS
      query: {
        bool: {
          must: [
            {
              query_string: {
                query: sanitized_query,
                fields: [ "title^3", "description^2", "tags" ],
                fuzziness: "AUTO",
                default_operator: "AND",
                escape: true
              }
            },
            {
              term: { project_id: project_id }
            }
          ]
        }
      }
    }).records
  end
end
