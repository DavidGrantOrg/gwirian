# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search indexing", type: :model do
  let(:project) { create(:project, workspace: create(:workspace)) }

  context "with the database backend", search_backend: :database do
    before do
      unreachable = Elasticsearch::Client.new(url: "http://127.0.0.1:9")
      [ Feature, Scenario, ScenarioExecution ].each do |model|
        allow(model.__elasticsearch__).to receive(:client).and_return(unreachable)
      end
    end

    it "saves and deletes features, scenarios and runs without a search server" do
      feature = create(:feature, project: project)
      scenario = create(:scenario, feature: feature)
      execution = create(:scenario_execution, scenario: scenario)

      execution.update!(notes: "Edited")
      scenario.update!(title: "Edited")
      feature.update!(title: "Edited")
      execution.destroy!
      scenario.destroy!
      feature.destroy!

      expect(Feature.exists?(feature.id)).to be(false)
    end
  end

  context "with the Elasticsearch backend", :elasticsearch do
    def indexed_title(feature)
      Feature.__elasticsearch__.client.get(index: Feature.index_name, id: feature.id)["_source"]["title"]
    end

    it "indexes a feature when it is created and updated, and removes it when deleted" do
      feature = create(:feature, project: project, title: "Checkout")
      expect(indexed_title(feature)).to eq("Checkout")

      feature.update!(title: "Basket")
      expect(indexed_title(feature)).to eq("Basket")

      feature.destroy!
      expect { indexed_title(feature) }.to raise_error(Elastic::Transport::Transport::Errors::NotFound)
    end
  end
end
