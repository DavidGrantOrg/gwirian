# frozen_string_literal: true

# Elasticsearch::Model::Callbacks, skipped when Gwirian searches the database instead.
module ElasticsearchIndexing
  extend ActiveSupport::Concern

  included do
    after_commit on: :create do
      __elasticsearch__.index_document if Gwirian.elasticsearch?
    end

    after_commit on: :update do
      __elasticsearch__.update_document if Gwirian.elasticsearch?
    end

    after_commit on: :destroy do
      __elasticsearch__.delete_document if Gwirian.elasticsearch?
    end
  end
end
