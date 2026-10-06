module Gwirian
  SIGNUP_MODES = %w[open invite_only].freeze

  class << self
    def saas?
      return @saas if defined?(@saas)
      @saas = !!(((ENV["SAAS"] || File.exist?(File.expand_path("../tmp/saas.txt", __dir__))) && ENV["SAAS"] != "false"))
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
