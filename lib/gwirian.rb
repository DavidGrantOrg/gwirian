module Gwirian
  SEARCH_BACKENDS = %w[elasticsearch database].freeze
  SIGNUP_MODES = %w[open invite_only].freeze

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

    # SIGNUP=invite_only lets only addresses Gwirian already knows, such as invited members, get a code.
    def invite_only_signup?
      mode = ENV.fetch("SIGNUP", "open")
      unless SIGNUP_MODES.include?(mode)
        raise ArgumentError, "SIGNUP must be \"open\" or \"invite_only\", not \"#{mode}\""
      end
      mode == "invite_only"
    end

    def configure_bundle
      if saas?
        ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
      end
    end
  end
end
