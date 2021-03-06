class InstChapter < ActiveRecord::Base
  #~ Relationships ............................................................
  belongs_to :inst_book
  has_many :inst_chapter_modules, dependent: :destroy

  #~ Validation ...............................................................
  #~ Constants ................................................................
  #~ Hooks ....................................................................
  #~ Class methods ............................................................
  def self.save_data_from_json(book, chapter_name, chapter_obj, chapter_position, update_mode=false)
    ch = InstChapter.where("inst_book_id = ? AND name = ?", book.id, chapter_name).first

    if !update_mode or (update_mode and !ch)
      ch = InstChapter.new
      ch.inst_book_id = book.id
      ch.name = chapter_name
    end
    ch.position = chapter_position
    ch.save

    mod_position = 1
    chapter_obj.each do |k, v|
      inst_module = InstModule.save_data_from_json(book, ch, k, v, mod_position, update_mode)
      mod_position += 1
    end
  end
  #~ Instance methods .........................................................
  # --------------------------------------------------------------------------
  # clone chapter
  def clone(inst_book)
    ch = InstChapter.new
    ch.inst_book_id = inst_book.id
    ch.name = self.name
    ch.short_display_name = self.short_display_name
    ch.position = self.position
    ch.save

    inst_chapter_modules.each do |chapter_module|
      inst_chapter_module = chapter_module.clone(inst_book, ch)
    end
  end

  def has_gradable_sections?
    gradable_section = false
    inst_chapter_modules.each do |chapter_module|
      chapter_module.inst_sections.each do |inst_section|
        gradable_section = inst_section.gradable
      end
    end
    return gradable_section
  end

  #~ Private instance methods .................................................
end
