require 'rubygems'
require 'sinatra'
require 'json'
require 'data_mapper'
require 'jsonapi-serializers'
require 'sinatra/cross_origin'
require 'sinatra/namespace'
require 'sinatra/form_helpers'

configure :development do
	require 'dm-sqlite-adapter'
	DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/db.db")
end

configure :test do
    require 'dm-sqlite-adapter'
    DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/test.db")
end

configure :production do
    require 'dm-postgres-adapter'
    DataMapper.setup(:default, 'postgres:postgres://alistair:Hash4214@localhost/gmm_volunteer')
end


register Sinatra::CrossOrigin
set :expose_headers, ['API_KEY']
set :allow_credentials, true
set :allow_origin, "http://localhost:4200,http://128.199.218.232"
configure do
  enable :cross_origin
end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['admin', 'admin']
  end
end

class Task
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :length => 500
  property :description, String, :length => 500
  property :additional, String, :length => 500
end

DataMapper.finalize

class BaseSerializer
  include JSONAPI::Serializer

  def self_link
    "http://128.199.218.232/api#{super}"
  end
end

class TaskSerializer < BaseSerializer
  attributes :title, :description, :additional
end

helpers do
  def parse_request_body
    return unless request.body.respond_to?(:size) &&
      request.body.size > 0

    halt 415 unless request.content_type &&
      request.content_type[/^[^;]+/] == mime_type(:api_json)

    request.body.rewind
    JSON.parse(request.body.read, symbolize_names: true)
  end

  # Convenience methods for serializing models:
  def serialize_model(model, options = {})
    options[:is_collection] = false
    options[:skip_collection_check] = true
    JSONAPI::Serializer.serialize(model, options)
  end

  def serialize_models(models, options = {})
    options[:is_collection] = true
    JSONAPI::Serializer.serialize(models, options)
  end
end

get '/migrate' do
	protected!
  DataMapper.auto_migrate!

  erb "Success"
end

get '/' do
 send_file 'index.html'
end

get '/tasks/new/?' do
  protected!
  @task = Task.new
  erb :task_new
end

get '/tasks/:id/edit/?' do
  protected!
  @task = Task.get(params[:id])
  erb :task_edit
end

get '/tasks/?' do
  protected!
  @tasks = Task.all
  erb :tasks
end

options "*" do
  response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"

  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, AUTHTOKEN"

  200
end

namespace '/api' do


  before do
    content_type :json
  end

  get '/tasks/?' do
    tasks = Task.all
    serialize_models(tasks).to_json
  end

  get '/tasks/:id/?' do
    task = Task.get(params[:id])
    serialize_model(task).to_json
  end

  post '/tasks/?' do
		protected!
    task = params[:task]
    Task.create(:title => task[:title], :description => task[:description], :additional => task[:additional])
    redirect :'tasks'
  end

  put '/tasks/:id/?' do
		protected!
    task = Task.get(params[:id])
    task.update(params[:task])
    redirect :'tasks'
  end

  delete '/tasks/:id/?' do
		protected!
    task = Task.get(params[:id])
    task.destroy
    redirect :'tasks'
  end
end
