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

    def configure_bundle
      if saas?
        ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
      end
    end
  end
end
