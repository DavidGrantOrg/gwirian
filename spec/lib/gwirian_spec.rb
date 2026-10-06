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
end
