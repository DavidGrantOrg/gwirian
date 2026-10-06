require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    around do |example|
      previous = ENV["SIGNUP"]
      example.run
    ensure
      ENV["SIGNUP"] = previous
    end

    def link_texts
      Nokogiri::HTML(response.body).css("a").map { |a| a.text.strip }
    end

    it "offers sign-up" do
      ENV.delete("SIGNUP")
      get "/session/new"
      expect(link_texts).to include("Sign up")
    end

    it "does not offer sign-up when it is invite-only" do
      ENV["SIGNUP"] = "invite_only"
      get "/session/new"
      expect(response).to have_http_status(:ok)
      expect(link_texts).not_to include("Sign up")
    end
  end
end
