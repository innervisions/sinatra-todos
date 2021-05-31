require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  set :port, 8080
  enable :sessions
  set :session_secret, "secret"
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

# Render the new list form
get "/lists/new" do
  erb :new_list
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  if (1..100).cover?(list_name.size)
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  else
    session[:error] = "List name must be between 1 and 100 characters."
    erb :new_list
  end
end
