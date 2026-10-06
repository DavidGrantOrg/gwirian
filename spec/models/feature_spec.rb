# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feature, type: :model do
  let(:project) { create(:project, workspace: create(:workspace)) }

  describe "#to_gherkin" do
    it "returns Feature line with title" do
      feature = create(:feature, project: project, title: "User authentication")
      expect(feature.to_gherkin).to include("Feature: User authentication")
    end

    it "includes description when present" do
      feature = create(:feature, project: project, title: "Auth", description: "As a user I want to log in")
      expect(feature.to_gherkin).to include("As a user I want to log in")
    end

    it "includes tags line when feature has tags" do
      feature = create(:feature, :with_tags, project: project, title: "Auth")
      gherkin = feature.to_gherkin
      expect(gherkin).to match(/@tag1 @tag2 @tag3/)
      expect(gherkin).to include("Feature: Auth")
    end

    it "writes a Background, data table included, that reads back as typed" do
      expected = <<~GHERKIN.chomp
        Feature: An AI agent reads Liquor Connect data

          Background:
            Given an AI agent signed in as the owner of a store that sells Captain Morgan White Rum, SKU 100234
            And Liquor Connect's catalogue, last imported on 2026-10-05, lists 100234 at 12 to a case, $300.00 a case, $1.20 deposit
            And Liquor Connect's future price changes, last imported on 2026-10-05, list
              | SKU    | Name                     | Change  | Effective  |
              | 100234 | Captain Morgan White Rum | +$1.50  | 2026-11-01 |
              | 801245 | Brancott Estate Sauv Bl  | -$2.00  | 2026-10-20 |

          Scenario: Looking up a product in Liquor Connect's catalogue
            When the agent looks up SKU 100234 in Liquor Connect's catalogue
            Then it gets 12 to a case, $300.00 a case and a $1.20 deposit
            And it is told the catalogue is as of 2026-10-05

          Scenario: Asking for upcoming price changes
            When the agent asks for upcoming Liquor Connect price changes
            Then it gets 100234 up $1.50 on 2026-11-01 and 801245 down $2.00 on 2026-10-20
      GHERKIN
      feature = create(:feature, project: project, title: "An AI agent reads Liquor Connect data", description: nil, background: <<~TEXT)
        an AI agent signed in as the owner of a store that sells Captain Morgan White Rum, SKU 100234
        Liquor Connect's catalogue, last imported on 2026-10-05, lists 100234 at 12 to a case, $300.00 a case, $1.20 deposit
        Liquor Connect's future price changes, last imported on 2026-10-05, list
        | SKU    | Name                     | Change  | Effective  |
        | 100234 | Captain Morgan White Rum | +$1.50  | 2026-11-01 |
        | 801245 | Brancott Estate Sauv Bl  | -$2.00  | 2026-10-20 |
      TEXT
      create(:scenario, feature: feature, title: "Looking up a product in Liquor Connect's catalogue", given: nil,
        when: "the agent looks up SKU 100234 in Liquor Connect's catalogue",
        then: "it gets 12 to a case, $300.00 a case and a $1.20 deposit\nAnd it is told the catalogue is as of 2026-10-05")
      create(:scenario, feature: feature, title: "Asking for upcoming price changes", given: nil,
        when: "the agent asks for upcoming Liquor Connect price changes",
        then: "it gets 100234 up $1.50 on 2026-11-01 and 801245 down $2.00 on 2026-10-20")

      expect(feature.reload.to_gherkin).to eq(expected)
    end

    it "leaves a blank line in a scenario's doc string without trailing spaces" do
      feature = create(:feature, project: project, title: "Notes", description: nil)
      create(:scenario, feature: feature, title: "Note", given: "the note reads\n\"\"\"\nline one\n\nline two\n\"\"\"")

      expect(feature.reload.to_gherkin.lines.map(&:chomp)).to include("      line one", "      line two")
      expect(feature.to_gherkin).not_to match(/ $/)
    end

    it "includes Background when present" do
      feature = create(:feature, project: project, title: "Auth", background: "User is on the site")
      expect(feature.to_gherkin).to include("Background:")
      expect(feature.to_gherkin).to include("Given User is on the site")
    end

    it "includes scenario blocks" do
      feature = create(:feature, project: project, title: "Cart")
      scenario = create(:scenario, feature: feature, title: "Add item")
      scenario.update_columns(given: "cart is empty", when: "user adds item", then: "cart has one item")
      scenario.reload
      gherkin = feature.to_gherkin
      expect(gherkin).to include("Feature: Cart")
      expect(gherkin).to include("Scenario: Add item")
      expect(gherkin).to include("Given cart is empty")
      expect(gherkin).to include("When user adds item")
      expect(gherkin).to include("Then cart has one item")
    end
  end
end
