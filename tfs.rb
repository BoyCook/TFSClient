#!/usr/bin/env ruby

# == Synopsis 
#   This will recursivly loop through a directory and it's subdirectories,
#   scanning file headers to see if they are tfa managed
#
# == Examples
#   Basic:
#     tfa 
#
# == Usage 
#   tfa [options] action group_id artefact_id version
#
#   For help use: tfa -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -V, --verbose       Verbose output
#
# == Author
#   Craig Cook
#
# == Copyright
#   Copyright (c) 2011 Craig Cook

require 'rdoc/usage'
require 'rexml/document'
require 'optparse' 
require 'ostruct'
require 'date'
require 'FileUtils'
require 'ftools'
require 'net/http'
require 'net/https'

include REXML

class String
  def starts_with?(prefix)
    self[0, prefix.length] == prefix
  end  
  
  def ends_with?(prefix)
    self[self.length - prefix.length, self.length] == prefix
  end  
end

class Finder
  def initialize(dir)
    @dir = dir
  end
  
  def run
    puts "Starting finder at: #{@dir}"
    find_files(@dir)
  end
  
  def find_files(dir)
  	Dir.foreach(dir) do |entry|   
  	  if File::directory?("#{dir}/#{entry}") and entry.match('^\.') then
  	    #Ignoring dirs begining with .
   		elsif File::directory?("#{dir}/#{entry}") then
        find_files("#{dir}/#{entry}")
      else 
	      loc = "#{dir}/#{entry}"
	      file = File.open(loc, 'r')
        ext = File.extname(loc)
        if is_tfa_managed? file then
	        values = read_header file
	        path = "#{ENV['HOME']}/.tfa/repository/"
          path = path + "#{values['groupId'].gsub(".", "/")}/#{values['artefactId']}/#{values['version']}"
          file_name = "#{values['artefactId']}-#{values['version']}#{ext}"
          file = "#{path}/#{file_name}"
          
          #TODO also check local meta data for cache expire
          if File::file?(file) then
            File.delete(loc)
            File.copy(file, loc)
            puts "Getting file from local repository: #{file}"                        
          else
            if !File::directory?(path) then
              puts "#{path} not found, creating..."
              FileUtils.mkpath path
            end            
            #TODO hit service for file location and get file
            puts "Getting file from web: #{file}"            
          end          
        end
   		end  	  
  	end    
  end
  
  def get_file(domain, path, file)
    Net::HTTP.start(domain) do |http|
        resp = http.get("#{path}/#{file}")
        open(file, "wb") do |file|
            file.write(resp.body)
        end
    end
  end
  
  def print_hash(hash)
    hash.each do | key, value |
      puts "Key [#{key}] Value [#{value}]"
    end    
  end
  
  def read_header(file)
    started = false
    values = {}
    
    file.each_line do |line|
      if line.strip.eql? '' and !started then      
        #Opening whitespace is ok        
      elsif line.strip.starts_with? '//' and !started then
        #Skipping initial comments
      elsif !line.strip.starts_with? '/*' and !started then
        #No opening comment header
        break                
      elsif line.strip.starts_with? '/*' and !started then
        started = true
      elsif line.strip.ends_with? '*/' and started then
        #You've reached the end of the opening comments
        break
      else #Parse the line
        if line.include? '@' and line.include? '>=' then
          key = line[line.index('@') + 1, line.index('>=') - 4].strip
          value = line[line.index('>=') + 2, line.length].strip
          values[key] = value
        end
      end
    end
    values
  end
  
  def is_tfa_managed?(file) 
    file.first.include? '@tfamanaged'
  end
end

class TFS
  def initialize
    @base_url = 'http://localhost:8080/tfs/service'
  end  
  
  def export(group_id, artefact_id, version)
    url = "#{@base_url}/files/#{group_id}/#{artefact_id}/#{version}/"
    puts "Getting meta-data from: #{url}"
    resp = Net::HTTP.get_response(URI.parse(url))
    doc = Document.new(resp.body)
    file_url = find_node(doc, 'url')    
    artefact_id = find_node(doc, 'artefactId')        
    group_id = find_node(doc, 'groupId')            
    version = find_node(doc, 'version')            
    extension = find_node(doc, 'extension')            
    file_name = "#{artefact_id}-#{version}.#{extension}"
    conf_name = "#{file_name}.tfs"
        
    if !File::directory?('.tfs') then
      Dir.mkdir('.tfs') 
    end
    
      # File.open(local_filename, 'a') {|f| f.write(doc) }          
    if !File::file?(".tfs/#{conf_name}") then
      File.open(".tfs/#{conf_name}", 'w') do |f| 
        f << "groupId=#{group_id}\n"
        f << "artefactId=#{artefact_id}\n"
        f << "version=#{version}\n"
        f << "fileName=#{file_name}\n"        
        f << "url=#{file_url}\n"
      end      
    end
    
    if File::file?(file_name) then
      puts "File #{file_name} already exists, consider an update instead"
    else
      download(file_url, file_name)      
    end
  end
  
  def find_node(doc, node)
    XPath.each(doc, "//#{node}") do |e| 
      return e.text
    end
  end  
  
  #TODO 404 etc handling
  def download(url, file_name)
    puts "Downloading file [#{file_name}] from: #{url}"    
    httpsuri = URI.parse(url)
    request = Net::HTTP.new(httpsuri.host, httpsuri.port)

    if httpsuri.port == 443
      request.use_ssl = true
      request.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    response = request.get(httpsuri.path)    
    
    open(file_name, "wb") do |file|
        file.write(response.body)
    end    
  end
end

class App_Runner
  VERSION = '0.0.1'
  attr_reader :options

  def initialize(arguments)    
    @arguments = arguments
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
  end  

  # Parse options, check arguments, then process the command
  def run
    if parsed_options? && arguments_valid? 
       puts "Start at #{DateTime.now}\n\n" if @options.verbose
       output_options if @options.verbose
       process_arguments            
       # setup
       start
       puts "\nFinished at #{DateTime.now}" if @options.verbose
     else
       output_usage
     end    
  end
  
  def start
    puts "Action: '#{@action}'"
    tfs = TFS.new()
    
    case @action
    when 'export'
      tfs.export(@group_id, @artefact_id, @version)
    when 'list'      
      #TODO hit service and list available items
    when 'update'
      #TODO find .tfs files and update
    when 'find'
      # finder = Finder.new(Dir.pwd)
      # finder.run    
    else
      puts "Unknown action #{@action} exiting"
    end
  end
  
  protected
    def setup
      home_dir = "#{ENV['HOME']}/.tfa"
      repo_dir = "#{home_dir}/repository"
      if !File::directory?(home_dir) then
        puts 'No tfa home, creating...'
        Dir.mkdir(home_dir) 
      end
      if !File::directory?(repo_dir) then
        puts 'No tfa repository home, creating...'
        Dir.mkdir(repo_dir) 
      end      
    end
  
    def parsed_options?
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')    { output_version ; exit 0 }
      opts.on('-h', '--help')       { output_help }
      opts.on('-V', '--verbose')    { @options.verbose = true }  
      opts.on('-q', '--quiet')      { @options.quiet = true }
      opts.parse!(@arguments) rescue return false
      process_options
      true      
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "#{name} = #{val}"
      end
    end

    def arguments_valid?
      true if @arguments.length >= 1
    end
    
    def process_arguments
      @action = @arguments[0]
      @group_id = @arguments[1]
      @artefact_id = @arguments[2]      
      @version = @arguments[3]
    end
    
    def output_help
      output_version
      RDoc::usage()
    end
    
    def output_usage
      RDoc::usage('usage')
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
end  

# Create and run the application
app = App_Runner.new(ARGV)
app.run

#ruby tfsclient/tfs.rb export org.cccs.jslibs jquery.collapsible 1.0.0
