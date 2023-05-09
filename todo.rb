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

def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
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

  # my solution before I saw LS solution:
  # general for both lists and todos, but that pushes it over the 10 line limit
  # (rubocop gets mad). it also uses a `list?` helper method for clarity,
  # but the code is just one line anyway: `session[:lists].include?(item)`.
  # def id_and_sort_by_completion(lists_or_todos)
  #   identified = {}

  #   lists_or_todos.each_with_index do |item, id|
  #     identified[item] = id
  #   end

  #   identified.sort_by do |item, _|
  #     if list?(item)
  #       list_complete?(item) ? 1 : 0
  #     else
  #       item[:completed] ? 1 : 0
  #     end
  #   end
  # end

  # my final version, combining the 2 LS methods:
  # yields lists or todos to block in correct order,
  # doesn't require calling #each on the return value.
  # rubocop flags the unused explicit block param `&block` so I dropped it.
  def sort_and_display(lists_or_todos)
    complete, incomplete = lists_or_todos.partition do |item|
      if session[:lists].include?(item) # if list
        list_complete?(item)
      else # if todo
        item[:completed]
      end
    end

    incomplete.each { |item| yield item, lists_or_todos.index(item) }
    complete.each { |item| yield item, lists_or_todos.index(item) }
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
    session[:lists] << { name: list_name, todos: [] }
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
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list_details # show list details for selected list
end

# Render the list edit form
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list # show form to edit selected list name
end

# Edit the list title
post "/lists/:list_id" do
  list_name = params[:list_name].strip

  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete the list
post "/lists/:list_id/delete" do
  session[:lists].delete_at(params[:list_id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a todo item to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  name = params[:todo].strip

  error = error_for_todo(name)
  if error
    session[:error] = error
    erb :list_details
  else
    session[:success] = "The todo was added."
    @list[:todos] << { name: name, completed: false }
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item from the list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update completion status of a todo item
post "/lists/:list_id/todos/:todo_id/check" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo = @list[:todos][params[:todo_id].to_i]

  if params[:completed] == 'false'
    todo[:completed] = false
  elsif params[:completed] == 'true'
    todo[:completed] = true
  end

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Complete all todos
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
