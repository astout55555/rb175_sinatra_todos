require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

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
  id = params[:id].to_i
  if (0...session[:lists].size).cover?(id)
    @list = session[:lists][id]
    @todos = @list[:todos]
    erb :list_details # show list details for selected list
  else
    session[:error] = "The specified list could not be found."
    redirect "/lists"
  end
end
