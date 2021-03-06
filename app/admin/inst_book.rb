ActiveAdmin.register InstBook, sort_order: :created_at_asc do
  filter :template
  includes :course_offering, :user
  config.clear_action_items!
  actions :all, except: [:new]

  menu :label => "Book Instances",parent: 'OpenDSA Books', priority: 20
  permit_params :template, :title, :desc, :course_offering_id, :user_id

  member_action :clone, method: :get do
  end

  member_action :destroy, method: :delete do
  end

  collection_action :upload_books, method: :get do
  end

  collection_action :upload_create, method: :post do
  end

  action_item only: :index do |inst_book|
    # link_to 'Upload Books', upload_books_admin_inst_books_path() if authorized? :upload_books, inst_book
    link_to 'Upload Books', upload_books_admin_inst_books_path(inst_book)
  end

  action_item only: :show  do
    link_to "Clone", clone_admin_inst_book_path(inst_book)
  end

  action_item only: [:show, :edit]  do
    message = confirmation_message(inst_book)
    link_to "Delete", { action: :destroy }, method: :delete, data: { confirm: message}
  end


  controller do
    def clone
      inst_book = InstBook.find(params[:id])
      title = inst_book.title
      cloned_inst_book = inst_book.clone(current_user)
      redirect_to admin_inst_books_path, notice: "Book instance ID:'#{inst_book.id}' title:'#{title}' was cloned successfully!. The new Book Instance ID is '#{cloned_inst_book.id}'"
    end

    def upload_books
      if !current_user.global_role.is_admin? and !current_user.global_role.is_instructor?
        redirect_to admin_inst_books_path
      end
    end

    def upload_create
      hash = JSON.load(File.read(params[:form][:file].path))
      InstBook.save_data_from_json(hash, current_user)

      redirect_to admin_inst_books_path, notice: 'Book configuration uploaded successfully!'
    end

    # --------------------------------------------------------------------------
    # inst_book cannot be template and linked to a course offering at the same time
    # in such cases reset the template flag
    def data_check(inst_book)
      if inst_book.course_offering_id and inst_book.template
        inst_book.template = false
      end
    end

    def destroy
      inst_book = InstBook.find(params[:id])
      title = inst_book.title
      inst_book.destroy
      redirect_to admin_inst_books_path, notice: "Book instance '#{title}' was deleted successfully!"
    end
  end

  before_save :data_check

  index do
    id_column
    column :title
    column :desc
    column :template
    if current_user.global_role.is_admin?
      column "Owner", :user
    end
    column :course_offering
    column :last_compiled
    column "Actions" do |inst_book|
      message = confirmation_message(inst_book)
      links = ''.html_safe
      if authorized? :update, inst_book
        links += link_to "Edit", edit_admin_inst_book_path(inst_book)
        links += ' '
      end
      if authorized? :destroy, inst_book
        links += link_to "Delete", admin_inst_book_path(inst_book), method: :delete, data: {confirm: message}
        links += ' '
      end
      links += link_to "Clone", clone_admin_inst_book_path(inst_book)
      links
    end

  end

  form do |f|
    f.semantic_errors *f.object.errors.keys
    f.inputs do
      if !f.object.template
        if f.object.last_compiled == nil or (f.object.last_compiled != nil and current_user.global_role.is_admin?)
          f.input :course_offering
        end
      end
      if current_user.global_role.is_admin?
        f.input :user
        if f.object.course_offering_id == nil
          f.input :template
        end
      end
      f.input :title
      f.input :desc
    end
    f.actions
  end

end