# frozen_string_literal: true

require "rails_helper"

RSpec.describe Gwirian do
  describe ".elasticsearch?" do
    around do |example|
      previous = ENV["SEARCH_BACKEND"]
      example.run
    ensure
      ENV["SEARCH_BACKEND"] = previous
    end

    it "is true when SEARCH_BACKEND is not set" do
      ENV.delete("SEARCH_BACKEND")
      expect(Gwirian.elasticsearch?).to be(true)
    end

    it "is true when SEARCH_BACKEND is elasticsearch" do
      ENV["SEARCH_BACKEND"] = "elasticsearch"
      expect(Gwirian.elasticsearch?).to be(true)
    end

    it "is false when SEARCH_BACKEND is database" do
      ENV["SEARCH_BACKEND"] = "database"
      expect(Gwirian.elasticsearch?).to be(false)
    end

    it "refuses an unknown SEARCH_BACKEND" do
      ENV["SEARCH_BACKEND"] = "databse"
      expect { Gwirian.elasticsearch? }.to raise_error(ArgumentError, 'SEARCH_BACKEND must be "elasticsearch" or "database", not "databse"')
    end
  end

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

  describe ".new_scenarios_in_backlog?" do
    around do |example|
      previous = ENV["NEW_SCENARIOS"]
      example.run
    ensure
      ENV["NEW_SCENARIOS"] = previous
    end

    it "is false when NEW_SCENARIOS is not set" do
      ENV.delete("NEW_SCENARIOS")
      expect(Gwirian.new_scenarios_in_backlog?).to be(false)
    end

    it "is false when NEW_SCENARIOS is active" do
      ENV["NEW_SCENARIOS"] = "active"
      expect(Gwirian.new_scenarios_in_backlog?).to be(false)
    end

    it "is true when NEW_SCENARIOS is backlog" do
      ENV["NEW_SCENARIOS"] = "backlog"
      expect(Gwirian.new_scenarios_in_backlog?).to be(true)
    end

    it "refuses an unknown NEW_SCENARIOS" do
      ENV["NEW_SCENARIOS"] = "backlogged"
      expect { Gwirian.new_scenarios_in_backlog? }.to raise_error(ArgumentError, 'NEW_SCENARIOS must be "active" or "backlog", not "backlogged"')
    end

    it "is checked when the app boots, so a mistyped value stops it starting" do
      ENV["NEW_SCENARIOS"] = "backlogged"
      expect { load Rails.root.join("config/initializers/new_scenarios.rb") }.to raise_error(ArgumentError, /NEW_SCENARIOS must be/)
    end
  end
end
