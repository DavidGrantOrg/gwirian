module Gwirian
  SEARCH_BACKENDS = %w[elasticsearch database].freeze
  SIGNUP_MODES = %w[open invite_only].freeze
  NEW_SCENARIOS_MODES = %w[active backlog].freeze

  class << self
    def saas?
      return @saas if defined?(@saas)
      @saas = !!(((ENV["SAAS"] || File.exist?(File.expand_path("../tmp/saas.txt", __dir__))) && ENV["SAAS"] != "false"))
    end

    # APP_NAME is the name users see; read on every call, unlike saas?, so a spec can change it.
    def app_name
      ENV["APP_NAME"].to_s.squish.presence || "Gwirian"
    end

    def renamed?
      !app_name.casecmp?("Gwirian")
    end

    # The static error pages in public/, with the name in their title, logo and 406 sentence following APP_NAME.
    def public_page(name)
      path = Rails.public_path.join("#{name}.html")
      html = path.read
      return html unless renamed?

      escaped = ERB::Util.html_escape(app_name)
      html.gsub(%r{ - Gwirian</title>|alt="Gwirian"|<span>Gwirian</span>|continue using Gwirian\.}) do |match|
        match.sub("Gwirian") { escaped }
      end
    rescue Errno::ENOENT
      Rails.logger.error("Error page #{path} is missing")
      raise
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

    # NEW_SCENARIOS=backlog puts each new scenario in the backlog, out of every count and rate.
    def new_scenarios_in_backlog?
      mode = ENV.fetch("NEW_SCENARIOS", "active")
      unless NEW_SCENARIOS_MODES.include?(mode)
        raise ArgumentError, "NEW_SCENARIOS must be \"active\" or \"backlog\", not \"#{mode}\""
      end
      mode == "backlog"
    end

    def configure_bundle
      if saas?
        ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
      end
    end
  end
end
