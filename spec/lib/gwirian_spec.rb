require "rails_helper"

RSpec.describe Gwirian do
  describe ".app_name" do
    it "is Gwirian when APP_NAME is unset", env: { "APP_NAME" => nil } do
      expect(Gwirian.app_name).to eq("Gwirian")
    end

    it "is APP_NAME when it is set", env: { "APP_NAME" => "Playbook" } do
      expect(Gwirian.app_name).to eq("Playbook")
    end

    it "is Gwirian when APP_NAME is blank", env: { "APP_NAME" => "  " } do
      expect(Gwirian.app_name).to eq("Gwirian")
    end

    it "collapses whitespace, newlines included, to single spaces", env: { "APP_NAME" => " Play\n  book " } do
      expect(Gwirian.app_name).to eq("Play book")
    end
  end

  describe ".renamed?" do
    [ nil, "", "  ", "Gwirian", "gwirian" ].each do |value|
      it "is false when APP_NAME is #{value.inspect}", env: { "APP_NAME" => value } do
        expect(Gwirian.renamed?).to be(false)
      end
    end

    it "is true when APP_NAME names something else", env: { "APP_NAME" => "Playbook" } do
      expect(Gwirian.renamed?).to be(true)
    end
  end

  describe ".public_page" do
    %w[400 404 406-unsupported-browser 422 500 503].each do |name|
      it "is #{name}.html byte for byte when not renamed", env: { "APP_NAME" => nil } do
        expect(Gwirian.public_page(name)).to eq(Rails.public_path.join("#{name}.html").read)
      end

      it "names APP_NAME and never Gwirian in #{name}.html when renamed", env: { "APP_NAME" => "Playbook" } do
        page = Gwirian.public_page(name)

        expect(page).not_to include("Gwirian")
        expect(page).to include("- Playbook</title>", 'alt="Playbook"', "<span>Playbook</span>")
      end
    end

    it "names APP_NAME in the 406 page's sentence", env: { "APP_NAME" => "Playbook" } do
      expect(Gwirian.public_page("406-unsupported-browser")).to include("continue using Playbook.")
    end

    it "escapes the name for HTML", env: { "APP_NAME" => %q(R&D "Lab") } do
      expect(Gwirian.public_page("404")).to include("<span>R&amp;D &quot;Lab&quot;</span>")
    end

    it "keeps a backslash in the name", env: { "APP_NAME" => 'Play\0book' } do
      expect(Gwirian.public_page("404")).to include('<span>Play\0book</span>')
    end

    it "logs a missing page with its path and raises" do
      allow(Rails.logger).to receive(:error)

      expect { Gwirian.public_page("418") }.to raise_error(Errno::ENOENT)
      expect(Rails.logger).to have_received(:error).with(a_string_including("public/418.html"))
    end
  end
end
