require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

class SessionPeristence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  private

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end
end

configure do
  set :erb, escape_html: true
  enable :sessions
  set :session_secret, "secret"
  # set :port, 8080
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists)
    lists.each { |list| yield(list) unless list_complete?(list) }
    lists.each { |list| yield(list) if list_complete?(list) }
  end

  def sort_todos(todos)
    todos.each { |todo| yield(todo) unless todo[:completed] }
    todos.each { |todo| yield(todo) if todo[:completed] }
  end
end

before do
  @storage = SessionPeristence.new(session)
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists
end

# Render the new list form
get "/lists/new" do
  erb :new_list
end

# Return an error message if name is invalid. Return nil if valid name.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

def load_list(index)
  target = @storage.find_list(index)
  return target if target

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list
end

# Edit an existing todo list.
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list
end

# Updates an existing todo list.
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Deletes a todo list.
post "/lists/:id/destroy" do
  id = params[:id].to_i
  @storage.delete_list(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Returns a message if a todo name is invalid.
def error_for_todo(name)
  return if (1..100).cover?(name.size)
  "Todo must be between 1 and 100 characters."
end

# Adds a todo to a list.
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Deletes a todo from a list.
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Updates the status of a todo.
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  is_completed = (params[:completed] == "true")
  target = @list[:todos].find { |todo| todo[:id] == todo_id }
  target[:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Completes all todos in a list.
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos completed."
  redirect "/lists/#{@list_id}"
end
