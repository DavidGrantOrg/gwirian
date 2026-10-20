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
end
