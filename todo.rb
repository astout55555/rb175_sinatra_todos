require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  erb :lists
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
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

get "/lists/:id" do
  @list_id = params[:id].to_i
  if (0...session[:lists].size).cover?(@list_id)
    @list = session[:lists][@list_id]
    @todos = @list[:todos]
    erb :list_details # show list details for selected list
  else
    session[:error] = "The specified list could not be found."
    redirect "/lists"
  end
end

# Render the list edit form
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  if (0...session[:lists].size).cover?(@list_id)
    @list = session[:lists][@list_id]
    erb :edit_list # show form to edit selected list name
  else
    session[:error] = "The specified list could not be found."
    redirect "/lists"
  end
end

# Edit the list title
post "/lists/:id" do
  list_name = params[:list_name].strip

  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

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
post "/lists/:id/delete" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# Add a todo item to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  name = params[:todo].strip

  error = error_for_todo(name)
  if error
    session[:error] = error
    erb :list_details
  else
    session[:success] = "The todo was added."
    @list[:todos] << {name: name, completed: false}
    redirect "/lists/#{@list_id}"
  end
end
