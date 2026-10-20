require "rails_helper"

RSpec.describe "Error pages", type: :request do
  # The test environment raises most errors into the spec and shows detailed pages for the rest; production does neither.
  around do |example|
    env_config = Rails.application.env_config
    previous = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env_config.merge!("action_dispatch.show_exceptions" => :all, "action_dispatch.show_detailed_exceptions" => false)
    example.run
  ensure
    env_config.merge!(previous)
  end

  let(:old_browser) { "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko" }

  def public_file(name)
    Rails.public_path.join("#{name}.html").read
  end

  context "when APP_NAME is unset" do
    it "serves the 404 page byte for byte" do
      get "/no-such-page"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq(public_file("404"))
    end

    it "serves the 500 page byte for byte" do
      allow_any_instance_of(SessionsController).to receive(:new).and_raise(RuntimeError, "boom")

      get "/session/new"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to eq(public_file("500"))
    end

    it "serves the unsupported-browser page byte for byte" do
      get "/session/new", headers: { "User-Agent" => old_browser }

      expect(response).to have_http_status(:not_acceptable)
      expect(response.body).to eq(public_file("406-unsupported-browser"))
    end
  end

  context "when APP_NAME is set", env: { "APP_NAME" => "Playbook" } do
    it "names APP_NAME on the 404 page" do
      get "/no-such-page"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("<title>Page Not Found (404) - Playbook</title>")
      expect(response.body).not_to include("Gwirian")
    end

    it "names APP_NAME on the 500 page" do
      allow_any_instance_of(SessionsController).to receive(:new).and_raise(RuntimeError, "boom")

      get "/session/new"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("<span>Playbook</span>")
      expect(response.body).not_to include("Gwirian")
    end

    it "names APP_NAME on the unsupported-browser page" do
      get "/session/new", headers: { "User-Agent" => old_browser }

      expect(response).to have_http_status(:not_acceptable)
      expect(response.body).to include("continue using Playbook.")
      expect(response.body).not_to include("Gwirian")
    end
  end

  [ nil, "Playbook" ].each do |app_name|
    context "when APP_NAME is #{app_name.inspect}", env: { "APP_NAME" => app_name } do
      it "answers a JSON request's 404 in JSON" do
        get "/no-such-page", headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to eq("status" => 404, "error" => "Not Found")
      end

      it "keeps the status and empty body of a 405, which has no page" do
        allow_any_instance_of(SessionsController).to receive(:new).and_raise(ActionController::MethodNotAllowed.new(:post))

        get "/session/new"

        expect(response).to have_http_status(:method_not_allowed)
        expect(response.body).to be_empty
      end

      it "keeps the status and empty body of a 409, which has no page" do
        allow_any_instance_of(SessionsController).to receive(:new).and_raise(ActiveRecord::StaleObjectError)

        get "/session/new"

        expect(response).to have_http_status(:conflict)
        expect(response.body).to be_empty
      end
    end
  end
end
