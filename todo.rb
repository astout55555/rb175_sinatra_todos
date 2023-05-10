require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

# Session Data Structure:
# session {
#   lists: [array of list hashes] # list_id based on array position
# }
  # list_hash {
  #   name: string
  #   todos: [array of todo hashes] # todo_id based on array position
  # }
    # todo_hash {
    #   name: string
    #   completed: boolean
    # }

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

not_found do
  "<html><body><h1>404 Not Found</h1></body></html>"
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def error_for_todo(name)
  return unless !(1..100).cover?(name.size)
  "Todo must be between 1 and 100 characters."
end

def load_list(list_id)
  session[:lists].each do |list|
    return list if list[:id] == list_id
  end

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

def next_id(lists_or_todos)
  max = lists_or_todos.map { |element| element[:id] }.max || 0
  max + 1
end

helpers do
  def list_complete?(list)
    !list[:todos].empty? && todos_remaining_count(list) == 0
  end

  def todos_remaining_count(list)
    todos = list[:todos]
    todos.reject { |todo| todo[:completed] }.size
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def sort_and_display(lists_or_todos, &block)
    complete, incomplete = lists_or_todos.partition do |element|
      if session[:lists].include?(element) # if list
        list_complete?(element)
      else # if todo
        element[:completed]
      end
    end

    incomplete.each(&block)
    complete.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    id = next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render the new list form
get "/lists/new" do
  erb :new_list
end
# Placed above the next route to avoid `:id` being set as 'new'

# View a single list
get "/lists/:list_id" do
  @list = load_list(params[:list_id].to_i)
  erb :list_details # show list details for selected list
end

# Render the list edit form
get "/lists/:list_id/edit" do
  @list = load_list(params[:list_id].to_i)
  erb :edit_list # show form to edit selected list name
end

# Edit the list title
post "/lists/:list_id" do
  list_name = params[:list_name].strip

  @list = load_list(params[:list_id].to_i)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list[:id]}"
  end
end

# Delete the list
post "/lists/:list_id/delete" do
  session[:lists].delete_if{ |list| list[:id] == params[:list_id].to_i }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"  
  end
end

# Add a todo item to a list
post "/lists/:list_id/todos" do
  @list = load_list(params[:list_id].to_i)
  name = params[:todo].strip

  error = error_for_todo(name)
  if error
    session[:error] = error
    erb :list_details
  else
    id = next_id(@list[:todos])
    @list[:todos] << { id: id, name: name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list[:id]}"
  end
end

# Delete a todo item from the list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list = load_list(params[:list_id].to_i)

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_if { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list[:id]}"
  end
end

# Update completion status of a todo item
post "/lists/:list_id/todos/:todo_id/check" do
  @list = load_list(params[:list_id].to_i)
  todo_id = params[:todo_id].to_i
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }

  if params[:completed] == 'false'
    todo[:completed] = false
  elsif params[:completed] == 'true'
    todo[:completed] = true
  end

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list[:id]}"
end

# Complete all todos
post "/lists/:list_id/complete_all" do
  @list = load_list(params[:list_id].to_i)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list[:id]}"
end
