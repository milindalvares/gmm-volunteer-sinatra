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
  def protected_ajax
    halt 401 unless request.env["HTTP_AUTHTOKEN"] == "58jdc60b-c891-9981-8821-939p0121609b"
  end
end

class Task
  include DataMapper::Resource

  property :id, Serial
  property :title, String
  property :description, String
  property :additional, String
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
  DataMapper.auto_migrate!
  Task.create(:title => "Test1", description: "Test Description1", :additional => "Additional test")
  Task.create(:title => "Test2", description: "Test Description2", :additional => "Additional test")
  Task.create(:title => "Test3", description: "Test Description3", :additional => "Additional test")

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

  get '/tasks' do
    tasks = Task.all
    serialize_models(tasks).to_json
  end

  get '/tasks/:id' do
    task = Task.get(params[:id])
    serialize_model(task).to_json
  end

  post '/tasks/?' do
    protected_ajax
    task = params[:task]
    Task.create(:title => task[:title], :description => task[:description], :additional => task[:additional])
    redirect :'tasks'
  end

  put '/tasks/:id' do
    protected_ajax
    task = Task.get(params[:id])
    task.update(params[:task])
    redirect :'tasks'
  end

  delete '/tasks/:id' do
    protected_ajax
    task = Task.get(params[:id])
    task.destroy
    redirect :'tasks'
  end
end
