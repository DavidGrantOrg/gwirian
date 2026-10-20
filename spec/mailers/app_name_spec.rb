require "rails_helper"

RSpec.describe "App name in mail", type: :mailer do
  let(:user) { create(:user) }
  let(:workspace_member) { create(:workspace_member, user: user) }

  before do
    allow(Rails.application.config.signup).to receive(:notify_email).and_return("admin@example.com")
  end

  def all_mails
    {
      "sign_in_instructions" => MagicLinkMailer.sign_in_instructions(MagicLink.create!(user: user)),
      "welcome" => UserMailer.welcome(user),
      "signup_notification" => UserMailer.signup_notification(user),
      "invite" => WorkspaceInvitationMailer.invite(workspace_member)
    }
  end

  # Subjects and decoded bodies only: the test environment's default From still says Gwirian.
  def texts(mail)
    [ mail.subject ] + mail.parts.map { |part| part.body.decoded }
  end

  it "says Gwirian with all rights reserved when APP_NAME is unset" do
    all_mails.each do |name, mail|
      mail.parts.each do |part|
        expect(part.body.decoded).to include("© #{Time.current.year} Gwirian. All rights reserved."), name
      end
    end
  end

  it "says APP_NAME, and never Gwirian, in every part of every mail when it is set", env: { "APP_NAME" => "Playbook" } do
    all_mails.each do |name, mail|
      texts(mail).each { |text| expect(text).not_to include("Gwirian"), "#{name}: #{text}" }
      mail.parts.each do |part|
        expect(part.body.decoded).to include("© #{Time.current.year} Playbook. All rights reserved."), name
      end
    end
  end

  it "names APP_NAME in the subjects that name the site", env: { "APP_NAME" => "R&D" } do
    mails = all_mails

    expect(mails["welcome"].subject).to eq("Welcome to R&D")
    expect(mails["sign_in_instructions"].subject).to start_with("Your R&D code is ")
  end
end
