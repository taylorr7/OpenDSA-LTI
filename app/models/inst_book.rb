  #~ Relationships ............................................................
  #~ Validation ...............................................................
  #~ Constants ................................................................
  #~ Hooks ....................................................................
  #~ Class methods ............................................................
  #~ Instance methods .........................................................
  #~ Private instance methods .................................................
class InstBook < ActiveRecord::Base

  #~ Relationships ............................................................
  belongs_to :course_offering, inverse_of: :inst_books
  belongs_to :user, inverse_of: :inst_books
  has_many :inst_chapters, dependent: :destroy
  has_many :inst_book_section_exercises, dependent: :destroy
  has_many :odsa_user_interactions
  has_many :odsa_book_progresses
  has_many :odsa_module_progresses
  has_many :odsa_exercise_attempts

  paginates_per 100

  #~ Validation ...............................................................
  #~ Constants ................................................................
  #~ Hooks ....................................................................
  #~ Class methods ............................................................
  def self.save_data_from_json(json, current_user)
    book_data = json
    update_mode = false
    inst_book_id = book_data['inst_book_id']
    options = {}
    options['build_dir'] = book_data['build_dir'] || "Books"
    options['code_dir'] = book_data['code_dir'] || "SourceCode/"
    options['lang'] = book_data['lang'] || "en"
    options['code_lang'] = book_data['code_lang'] || {}
    options['build_JSAV'] = book_data['build_JSAV'] || false
    options['tabbed_codeinc'] = book_data['tabbed_codeinc'] || false
    options['build_cmap'] = book_data['build_cmap'] || false
    options['suppress_todo'] = book_data['suppress_todo'] || true
    options['assumes'] = book_data['assumes'] || "recursion"
    options['dispModComp'] = book_data['dispModComp'] || true
    options['glob_exer_options'] = book_data['glob_exer_options'] || {}

    if inst_book_id == nil
      b = InstBook.new
      b.user_id = current_user.id
      b.template = true
    else
      b = InstBook.find_by(id: inst_book_id)
      update_mode = true
    end
    b.title = book_data['title']
    b.desc = book_data['desc']

    require 'json'
    b.options = options.to_json
    b.save

    chapters = book_data['chapters']

    ch_position = 0
    chapters.each do |k,v|
      inst_chapter = InstChapter.save_data_from_json(b, k, v, ch_position, update_mode)
      ch_position += 1
    end
  end

  #~ Instance methods .........................................................
  # --------------------------------------------------------------------------
  # return lms credintials associated with the course offering
  def lms_creds
    consumer_key = course_offering.lms_instance['consumer_key']
    consumer_secret = course_offering.lms_instance['consumer_secret']
    {consumer_key => consumer_secret}
  end

  # --------------------------------------------------------------------------
  # clone book configuration
  def clone(current_user)
      b = InstBook.new
      b.title = self.title
      b.desc = self.desc
      b.options = self.options
      b.user_id = current_user.id
      b.save

      inst_chapters.each do |chapter|
        inst_chapter = chapter.clone(b)
      end
      return b
  end
  #~ Private instance methods .................................................
end
