# frozen_string_literal: true

require "rails_helper"

RSpec.describe Folder, type: :model do
  let(:project) { create(:project) }

  describe "names" do
    it "refuses a folder with no name" do
      folder = build(:folder, project: project, name: "")
      expect(folder).not_to be_valid
      expect(folder.errors[:name]).to include("can't be blank")
    end

    it "refuses a name longer than 255 characters" do
      expect(build(:folder, project: project, name: "a" * 256)).not_to be_valid
      expect(build(:folder, project: project, name: "a" * 255)).to be_valid
    end

    it "refuses two top-level folders with the same name, whatever the case" do
      create(:folder, project: project, name: "Ordering")
      folder = build(:folder, project: project, name: "ordering")
      expect(folder).not_to be_valid
      expect(folder.errors[:name]).to include("is already used by another folder here")
    end

    it "refuses two folders with the same name under one parent" do
      parent = create(:folder, project: project, name: "Ordering")
      create(:folder, project: project, parent: parent, name: "Suggested orders")
      expect(build(:folder, project: project, parent: parent, name: "Suggested Orders")).not_to be_valid
    end

    it "allows the same name under different parents" do
      ordering = create(:folder, project: project, name: "Ordering")
      catalog = create(:folder, project: project, name: "Catalog")
      create(:folder, project: project, parent: ordering, name: "Imports")
      expect(build(:folder, project: project, parent: catalog, name: "Imports")).to be_valid
      expect(build(:folder, project: project, name: "Imports")).to be_valid
    end

    it "allows the same top-level name in another project" do
      create(:folder, project: project, name: "Ordering")
      expect(build(:folder, project: create(:project), name: "Ordering")).to be_valid
    end

    it "keeps a top-level name unique in the database, where NULL parents would otherwise all differ" do
      create(:folder, project: project, name: "Ordering")
      duplicate = build(:folder, project: project, name: "ORDERING")
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "parents" do
    it "refuses a parent from another project" do
      other = create(:folder, project: create(:project))
      folder = build(:folder, project: project, parent: other)
      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to include("must be in the same project")
    end

    it "refuses a folder as its own parent" do
      folder = create(:folder, project: project)
      folder.parent = folder
      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to include("can't be the folder itself or one of its sub-folders")
    end

    it "refuses a move inside one of its own sub-folders" do
      top = create(:folder, project: project, name: "Ordering")
      middle = create(:folder, project: project, parent: top, name: "Suggested orders")
      bottom = create(:folder, project: project, parent: middle, name: "History")
      top.parent = bottom
      expect(top).not_to be_valid
      expect(top.errors[:parent]).to include("can't be the folder itself or one of its sub-folders")
    end

    it "allows a move under a sibling" do
      ordering = create(:folder, project: project, name: "Ordering")
      catalog = create(:folder, project: project, name: "Catalog")
      ordering.parent = catalog
      expect(ordering).to be_valid
    end
  end

  describe "#path" do
    it "lists the folder and its parents from the top down" do
      top = create(:folder, project: project, name: "Ordering")
      middle = create(:folder, project: project, parent: top, name: "Suggested orders")
      bottom = create(:folder, project: project, parent: middle, name: "History")
      expect(bottom.path).to eq([ top, middle, bottom ])
    end

    it "is the folder alone at the top level" do
      folder = create(:folder, project: project)
      expect(folder.path).to eq([ folder ])
    end
  end

  describe "deleting" do
    it "moves its features and sub-folders into its parent" do
      top = create(:folder, project: project, name: "Ordering")
      middle = create(:folder, project: project, parent: top, name: "Suggested orders")
      bottom = create(:folder, project: project, parent: middle, name: "History")
      feature = create(:feature, project: project, folder: middle)

      middle.destroy!

      expect(bottom.reload.parent).to eq(top)
      expect(feature.reload.folder).to eq(top)
    end

    it "moves a top-level folder's contents to the top level" do
      top = create(:folder, project: project, name: "Ordering")
      child = create(:folder, project: project, parent: top, name: "History")
      feature = create(:feature, project: project, folder: top)

      top.destroy!

      expect(child.reload.parent).to be_nil
      expect(feature.reload.folder).to be_nil
      expect(project.features.reload).to include(feature)
    end

    it "is refused when a sub-folder's name is already taken in the parent" do
      ordering = create(:folder, project: project, name: "Ordering")
      create(:folder, project: project, parent: ordering, name: "Imports")
      create(:folder, project: project, name: "imports")

      expect(ordering.destroy).to be(false)
      expect(ordering.errors[:base]).to include("Can't delete Ordering: the top level already has a folder named Imports")
      expect(Folder.exists?(ordering.id)).to be(true)
    end

    it "is refused by the database when the contents are not moved first" do
      top = create(:folder, project: project)
      create(:feature, project: project, folder: top)
      expect { top.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  it "goes with its project" do
    folder = create(:folder, project: project)
    create(:feature, project: project, folder: folder)
    create(:folder, project: project, parent: folder)

    project.destroy!

    expect(Folder.where(project_id: project.id)).to be_empty
  end

  describe "abilities" do
    let(:user) { create(:user) }
    let(:folder) { create(:folder, project: project) }

    def ability_with_role(role)
      create(:project_member, project: project, email: user.email_address, role: role) if role
      Ability.new(user)
    end

    it "lets a viewer read but not change a folder" do
      ability = ability_with_role("viewer")
      expect(ability.can?(:read, folder)).to be(true)
      expect(ability.can?(:create, folder)).to be(false)
      expect(ability.can?(:update, folder)).to be(false)
      expect(ability.can?(:destroy, folder)).to be(false)
    end

    it "lets an editor create, update and delete a folder" do
      ability = ability_with_role("editor")
      expect(ability.can?(:create, folder)).to be(true)
      expect(ability.can?(:update, folder)).to be(true)
      expect(ability.can?(:destroy, folder)).to be(true)
    end

    it "lets an administrator create, update and delete a folder" do
      ability = ability_with_role("administrator")
      expect(ability.can?(:create, folder)).to be(true)
      expect(ability.can?(:update, folder)).to be(true)
      expect(ability.can?(:destroy, folder)).to be(true)
    end

    it "gives someone outside the project nothing" do
      ability = ability_with_role(nil)
      expect(ability.can?(:read, folder)).to be(false)
      expect(ability.can?(:update, folder)).to be(false)
    end
  end
end
