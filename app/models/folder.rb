class Folder < ApplicationRecord
  belongs_to :project
  # No parent means the folder sits at the top of the project.
  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent
  has_many :features

  validates :name, presence: true, length: { maximum: 255 }
  validate :name_unique_among_siblings
  validate :parent_in_same_project
  validate :parent_outside_own_subtree

  # The foreign keys have no ON DELETE, so the database refuses a delete that skips this.
  before_destroy :move_contents_to_parent

  # The folder and its parents, from the top of the project down.
  def path
    folders = [ self ]
    folders.unshift(folders.first.parent) while folders.first.parent
    folders
  end

  private

  def name_unique_among_siblings
    return if name.blank? || project.nil?

    siblings = project.folders.where(parent_id: parent_id).where("lower(name) = ?", name.downcase)
    siblings = siblings.where.not(id: id) if persisted?
    errors.add(:name, "is already used by another folder here") if siblings.exists?
  end

  def parent_in_same_project
    errors.add(:parent, "must be in the same project") if parent && parent.project_id != project_id
  end

  def parent_outside_own_subtree
    return unless persisted? && parent

    ancestor = parent
    while ancestor
      if ancestor.id == id
        errors.add(:parent, "can't be the folder itself or one of its sub-folders")
        return
      end
      ancestor = ancestor.parent
    end
  end

  def move_contents_to_parent
    taken = project.folders.where(parent_id: parent_id).where.not(id: id).pluck(:name).map(&:downcase)
    clash = children.find { |child| taken.include?(child.name.downcase) }
    if clash
      where = parent ? parent.name : "the top level"
      errors.add(:base, "Can't delete #{name}: #{where} already has a folder named #{clash.name}")
      throw :abort
    end

    features.update_all(folder_id: parent_id)
    children.update_all(parent_id: parent_id)
  end
end
