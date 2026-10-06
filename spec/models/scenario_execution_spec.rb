# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScenarioExecution, type: :model do
  describe ".search_by_project with the database backend", search_backend: :database do
    let(:project) { create(:project, workspace: create(:workspace)) }
    let(:checkout) { create(:scenario, feature: create(:feature, project: project, title: "Checkout"), title: "Pay by card") }
    let(:login) { create(:scenario, feature: create(:feature, project: project, title: "Login"), title: "Sign in") }
    let(:alice) { create(:user, email_address: "alice@example.com") }
    let(:bob) { create(:user, email_address: "bob@example.com") }
    let!(:paid) do
      create(:scenario_execution, scenario: checkout, user: alice, status: "passed", notes: "Visa accepted", executed_at: 2.days.ago)
    end
    let!(:signed_in) do
      create(:scenario_execution, scenario: login, user: bob, status: "failed", notes: "Code expired", executed_at: 1.day.ago)
    end

    def search(query)
      ScenarioExecution.search_by_project(query, project.id).to_a
    end

    it "matches the feature title, scenario title, tester's email, status and notes" do
      expect(search("checkout")).to eq([ paid ])
      expect(search("sign")).to eq([ signed_in ])
      expect(search("alice")).to eq([ paid ])
      expect(search("failed")).to eq([ signed_in ])
      expect(search("visa")).to eq([ paid ])
    end

    it "matches a tag" do
      signed_in.update!(tag_list: "smoke")
      expect(search("smoke")).to eq([ signed_in ])
    end

    it "requires every word to match" do
      expect(search("login expired")).to eq([ signed_in ])
      expect(search("login visa")).to eq([])
    end

    it "lists the newest run first" do
      expect(search("example.com")).to eq([ signed_in, paid ])
    end

    it "leaves out other projects' runs" do
      other_scenario = create(:scenario, feature: create(:feature, project: create(:project, workspace: project.workspace), title: "Checkout"))
      create(:scenario_execution, scenario: other_scenario, user: alice)
      expect(search("checkout")).to eq([ paid ])
    end
  end
end
