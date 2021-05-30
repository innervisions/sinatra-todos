require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
set :port, 8080

get "/" do
  erb "You have no lists.", layout: :layout
end
