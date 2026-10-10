# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  let(:workspace) { create(:workspace) }
  let(:project) { create(:project, workspace: workspace, name: "My Project", description: "Project desc", context: "env: test") }

  describe "#to_gherkin" do
    it "includes project header with name" do
      expect(project.to_gherkin).to include("# Project: My Project")
    end

    it "includes description in header when present" do
      expect(project.to_gherkin).to include("# Description: Project desc")
    end

    it "includes context in header when present" do
      expect(project.to_gherkin).to include("# Context")
      expect(project.to_gherkin).to include("env: test")
    end

    it "includes all features Gherkin" do
      f1 = create(:feature, project: project, title: "Login")
      create(:scenario, feature: f1, title: "Sign in")
      gherkin = project.to_gherkin
      expect(gherkin).to include("Feature: Login")
      expect(gherkin).to include("Scenario: Sign in")
    end
  end

  describe "#gherkin_export_entries" do
    it "returns array of [filename, content] pairs" do
      entries = project.gherkin_export_entries
      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
    end

    it "first entry is project_info.md with project metadata" do
      entries = project.gherkin_export_entries
      expect(entries.first[0]).to eq("project_info.md")
      content = entries.first[1]
      expect(content).to include("# My Project")
      expect(content).to include("## Description")
      expect(content).to include("Project desc")
      expect(content).to include("env: test")
    end

    it "includes one .feature file per feature with slugged filename" do
      create(:feature, project: project, title: "User Login")
      create(:feature, project: project, title: "Checkout Flow")
      entries = project.gherkin_export_entries
      filenames = entries.map(&:first)
      expect(filenames).to include("user-login.feature")
      expect(filenames).to include("checkout-flow.feature")
    end

    it "feature file content is valid Gherkin" do
      f = create(:feature, project: project, title: "Auth")
      create(:scenario, feature: f, title: "Login")
      entries = project.gherkin_export_entries
      feature_entry = entries.find { |name, _| name == "auth.feature" }
      expect(feature_entry).to be_present
      expect(feature_entry[1]).to include("Feature: Auth")
      expect(feature_entry[1]).to include("Scenario: Login")
    end

    it "suffixes duplicate slug with number to avoid overwrite" do
      create(:feature, project: project, title: "Login")
      create(:feature, project: project, title: "Login")
      entries = project.gherkin_export_entries
      filenames = entries.map(&:first)
      expect(filenames).to include("login.feature")
      expect(filenames).to include("login-1.feature")
    end

    context "with folders" do
      let!(:ordering) { create(:folder, project: project, name: "Ordering") }
      let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }

      def filenames
        project.gherkin_export_entries.map(&:first)
      end

      it "puts a foldered feature in its folder's directories and an unfiled one at the top" do
        create(:feature, project: project, title: "Reorder from history", folder: suggested)
        create(:feature, project: project, title: "Sign in")

        expect(filenames).to eq([ "project_info.md", "ordering/suggested-orders/reorder-from-history.feature", "sign-in.feature" ])
      end

      it "checks for clashing file names in each directory separately" do
        create(:feature, project: project, title: "Login", folder: ordering)
        create(:feature, project: project, title: "Login", folder: suggested)
        create(:feature, project: project, title: "Login", folder: suggested)
        create(:feature, project: project, title: "Login")

        expect(filenames).to contain_exactly(
          "project_info.md", "login.feature", "ordering/login.feature",
          "ordering/suggested-orders/login.feature", "ordering/suggested-orders/login-1.feature"
        )
      end

      it "adds the folder id to a sibling whose directory name clashes" do
        first = create(:folder, project: project, parent: ordering, name: "Imports!")
        second = create(:folder, project: project, parent: ordering, name: "Imports?")
        create(:folder, project: project, name: "Imports")
        create(:feature, project: project, title: "A", folder: first)
        create(:feature, project: project, title: "B", folder: second)

        expect(filenames).to include("ordering/imports/a.feature", "ordering/imports-#{second.id}/b.feature")
      end
    end
  end

  describe "#search_content", search_backend: :database do
    let(:feature) { create(:feature, project: project, title: "Checkout") }

    def feature_status
      project.search_content("checkout").find { |r| r[:type] == "feature" }[:status]
    end

    it "leaves backlog scenarios out of a feature's status" do
      create(:scenario_execution, scenario: create(:scenario, feature: feature), status: "passed")
      create(:scenario, :backlog, feature: feature)
      expect(feature_status).to eq("passed")
    end

    it "reads backlog for a feature whose scenarios are all in the backlog" do
      create(:scenario_execution, scenario: create(:scenario, :backlog, feature: feature), status: "failed")
      expect(feature_status).to eq("backlog")
    end
  end
end
