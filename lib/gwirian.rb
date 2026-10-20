module Gwirian
  class << self
    def saas?
      return @saas if defined?(@saas)
      @saas = !!(((ENV["SAAS"] || File.exist?(File.expand_path("../tmp/saas.txt", __dir__))) && ENV["SAAS"] != "false"))
    end

    # APP_NAME is the name users see; read on every call, unlike saas?, so a spec can change it.
    def app_name
      ENV["APP_NAME"].to_s.squish.presence || "Gwirian"
    end

    def configure_bundle
      if saas?
        ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
      end
    end
  end
end
