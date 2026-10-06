# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scenario, type: :model do
  describe "#to_gherkin" do
    let(:feature) { create(:feature, project: create(:project, workspace: create(:workspace))) }

    it "returns Scenario line with title" do
      scenario = create(:scenario, feature: feature, title: "User logs in")
      expect(scenario.to_gherkin).to include("Scenario: User logs in")
    end

    it "includes Given when present" do
      scenario = create(:scenario, feature: feature, title: "Login", given: "the user is on the login page")
      expect(scenario.to_gherkin).to include("Given the user is on the login page")
    end

    it "includes When when present" do
      scenario = create(:scenario, feature: feature, title: "Login")
      scenario.update_columns(given: nil, when: "the user submits credentials", then: nil)
      scenario.reload
      expect(scenario.to_gherkin).to include("When the user submits credentials")
    end

    it "includes Then when present" do
      scenario = create(:scenario, feature: feature, title: "Login")
      scenario.update_columns(given: nil, when: nil, then: "the user sees the dashboard")
      scenario.reload
      expect(scenario.to_gherkin).to include("Then the user sees the dashboard")
    end

    it "includes all three steps when present" do
      scenario = create(:scenario, feature: feature, title: "Add to cart")
      scenario.update_columns(
        given: "the user is viewing a product",
        when: "the user clicks Add to Cart",
        then: "the cart shows one item"
      )
      scenario.reload
      gherkin = scenario.to_gherkin
      expect(gherkin).to include("Scenario: Add to cart")
      expect(gherkin).to include("Given the user is viewing a product")
      expect(gherkin).to include("When the user clicks Add to Cart")
      expect(gherkin).to include("Then the cart shows one item")
    end

    it "writes And before each later line of a step" do
      scenario = create(:scenario, feature: feature, title: "Stock", given: "the store is open\nthe shelf is empty")
      expect(scenario.to_gherkin).to eq("Scenario: Stock\n  Given the store is open\n  And the shelf is empty")
    end

    it "keeps a keyword typed at the start of a line" do
      scenario = create(:scenario, feature: feature, title: "Stock", given: "Given the store is open\nBut the shelf is empty\n* the till is on")
      expect(scenario.to_gherkin).to eq("Scenario: Stock\n  Given the store is open\n  But the shelf is empty\n  * the till is on")
    end

    it "indents a data table under its step, keeping its padding" do
      scenario = create(:scenario, feature: feature, title: "Prices", given: "price changes list\n| SKU    | Change |\n| 100234 | +$1.50 |")
      expect(scenario.to_gherkin).to eq("Scenario: Prices\n  Given price changes list\n    | SKU    | Change |\n    | 100234 | +$1.50 |")
    end

    it "indents a doc string under its step, keeping its own indentation and blank lines" do
      scenario = create(:scenario, feature: feature, title: "Note", given: "the note reads\n\"\"\"\nline one\n\n  indented\n\"\"\"\nthe note is saved")
      expect(scenario.to_gherkin).to eq(
        "Scenario: Note\n  Given the note reads\n    \"\"\"\n    line one\n\n      indented\n    \"\"\"\n  And the note is saved"
      )
    end

    it "omits empty steps" do
      scenario = create(:scenario, feature: feature, title: "Minimal")
      scenario.update_columns(given: nil, when: nil, then: nil)
      scenario.reload
      expect(scenario.to_gherkin).to eq("Scenario: Minimal")
    end
  end
end
