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

  describe ".search_by_project with the database backend", search_backend: :database do
    let!(:checkout) { create(:feature, project: project, title: "Checkout", description: "Pay for the basket") }
    let!(:login) { create(:feature, project: project, title: "Login", description: "Sign in with a code") }

    def search(query, limit: 100)
      Feature.search_by_project(query, project.id, limit: limit).to_a
    end

    it "matches a word in the title or description" do
      expect(search("basket")).to eq([ checkout ])
    end

    it "requires every word to match" do
      expect(search("basket pay")).to eq([ checkout ])
      expect(search("basket code")).to eq([])
    end

    it "ignores case" do
      expect(search("CHECKOUT")).to eq([ checkout ])
    end

    it "matches part of a word" do
      expect(search("heck")).to eq([ checkout ])
    end

    it "matches a tag" do
      login.update!(tag_list: "authentication")
      expect(search("authentic")).to eq([ login ])
    end

    it "leaves out other projects' features" do
      create(:feature, project: create(:project, workspace: project.workspace), title: "Checkout")
      expect(search("checkout")).to eq([ checkout ])
    end

    it "treats % and _ as ordinary characters" do
      half_off = create(:feature, project: project, title: "50% off", description: "snake_case")
      create(:feature, project: project, title: "500 off", description: "snakeXcase")
      expect(search("50%")).to eq([ half_off ])
      expect(search("snake_case")).to eq([ half_off ])
    end

    it "returns at most limit features" do
      expect(search("in", limit: 1).size).to eq(1)
    end
  end
end
