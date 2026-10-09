FactoryBot.define do
  factory :folder do
    association :project
    sequence(:name) { |n| "Folder #{n}" }
  end
end
