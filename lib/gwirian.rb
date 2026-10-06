module Gwirian
  SEARCH_BACKENDS = %w[elasticsearch database].freeze

  class << self
    def saas?
      return @saas if defined?(@saas)
      @saas = !!(((ENV["SAAS"] || File.exist?(File.expand_path("../tmp/saas.txt", __dir__))) && ENV["SAAS"] != "false"))
    end

    # SEARCH_BACKEND=database searches with SQL and never contacts Elasticsearch.
    def elasticsearch?
      backend = ENV.fetch("SEARCH_BACKEND", "elasticsearch")
      unless SEARCH_BACKENDS.include?(backend)
        raise ArgumentError, "SEARCH_BACKEND must be \"elasticsearch\" or \"database\", not \"#{backend}\""
      end
      backend == "elasticsearch"
    end

    def configure_bundle
      if saas?
        ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
      end
    end
  end
end
