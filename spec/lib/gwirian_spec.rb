# frozen_string_literal: true

require "rails_helper"

RSpec.describe Gwirian do
  describe ".invite_only_signup?" do
    around do |example|
      previous = ENV["SIGNUP"]
      example.run
    ensure
      ENV["SIGNUP"] = previous
    end

    it "is false when SIGNUP is not set" do
      ENV.delete("SIGNUP")
      expect(Gwirian.invite_only_signup?).to be(false)
    end

    it "is false when SIGNUP is open" do
      ENV["SIGNUP"] = "open"
      expect(Gwirian.invite_only_signup?).to be(false)
    end

    it "is true when SIGNUP is invite_only" do
      ENV["SIGNUP"] = "invite_only"
      expect(Gwirian.invite_only_signup?).to be(true)
    end

    it "refuses an unknown SIGNUP" do
      ENV["SIGNUP"] = "invite-only"
      expect { Gwirian.invite_only_signup? }.to raise_error(ArgumentError, 'SIGNUP must be "open" or "invite_only", not "invite-only"')
    end
  end
end
