# Examples tagged `search_backend: :database` run with SEARCH_BACKEND set to that value.
# Examples tagged `elasticsearch: true` need a running Elasticsearch and are skipped
# when the suite itself runs with SEARCH_BACKEND=database.
RSpec.configure do |config|
  config.around(:each, :search_backend) do |example|
    previous = ENV["SEARCH_BACKEND"]
    ENV["SEARCH_BACKEND"] = example.metadata[:search_backend].to_s
    example.run
  ensure
    ENV["SEARCH_BACKEND"] = previous
  end

  config.filter_run_excluding elasticsearch: true if ENV["SEARCH_BACKEND"] == "database"
end
