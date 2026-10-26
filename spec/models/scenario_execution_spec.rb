# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScenarioExecution, type: :model do
  describe ".latest_first" do
    it "puts the run recorded later first when two ran at the same time" do
      at = 1.hour.ago
      first = create(:scenario_execution, status: "failed", executed_at: at)
      second = create(:scenario_execution, status: "failed", executed_at: at)
      expect(ScenarioExecution.failed.latest_first.to_a).to eq([ second, first ])
    end
  end

  describe ".latest_for" do
    let(:feature) { create(:feature) }
    let(:checkout) { create(:scenario, feature: feature) }
    let(:login) { create(:scenario, feature: feature) }

    def latest_for(scenarios, **options)
      ScenarioExecution.latest_for(scenarios, **options).to_a
    end

    it "returns each scenario's newest run by when it ran, not when it was recorded" do
      newest = create(:scenario_execution, scenario: checkout, executed_at: 1.hour.ago)
      create(:scenario_execution, scenario: checkout, executed_at: 2.hours.ago)
      expect(latest_for(Scenario.where(id: checkout))).to eq([ newest ])
    end

    it "returns the run recorded later when two ran at the same time" do
      at = 1.hour.ago
      create(:scenario_execution, scenario: checkout, executed_at: at)
      later = create(:scenario_execution, scenario: checkout, executed_at: at)
      expect(latest_for(Scenario.where(id: checkout))).to eq([ later ])
    end

    it "returns one run for each scenario given, and none for a scenario never run" do
      checkout_run = create(:scenario_execution, scenario: checkout)
      login_run = create(:scenario_execution, scenario: login)
      never_run = create(:scenario, feature: feature)
      expect(latest_for(Scenario.where(id: [ checkout, login, never_run ]))).to contain_exactly(checkout_run, login_run)
    end

    it "leaves out the runs of scenarios not given" do
      create(:scenario_execution, scenario: login)
      expect(latest_for(Scenario.where(id: checkout))).to eq([])
    end

    it "with at_or_before, returns the newest run at or before that time" do
      cutoff = 1.day.ago
      at_cutoff = create(:scenario_execution, scenario: checkout, executed_at: cutoff)
      create(:scenario_execution, scenario: checkout, executed_at: 1.hour.ago)
      expect(latest_for(Scenario.where(id: checkout), at_or_before: cutoff)).to eq([ at_cutoff ])
    end
  end

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
