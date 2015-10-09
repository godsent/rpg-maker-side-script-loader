($imported ||={})["Side_Scripts_Loaders"] = true#Add script to $imported
module Kernel#Force UTF-8
  alias fix_load_data load_data
  def load_data(file)
    data = fix_load_data(file)
    if data.kind_of?(String)
      data.force_encoding('UTF-8')
    end
    data
  end
end

class RequireLoader
  #set to false if you do not want to compress 
  #all the scripts to batch.rb file 
  BATCH =  true
 
  module ToInclude
    def require(path)
      if RequireLoader.batch?
        RequireLoader.new(path).load
      else
        begin
          super
        rescue Exception => e
          RequireLoader.new(path).load
        end
      end
    end
  end
  
  class << self
    attr_accessor :binding
    attr_writer :batch_file_created

    def pathes
      @pathes ||= []
    end

    def batch_file_created?
      !!@batch_file_created
    end

    def batch?
      !!BATCH
    end

    def enabled?
      return true if batch?
      Dir.pwd.encode 'utf-8'
      false
    rescue Encoding::UndefinedConversionError
      true
    end
        
    def batch_file_mode
      RequireLoader.batch_file_created? ? 'a' : 'w'
    end
    
    def write_to_batch(ruby_code, file_path)
      File.open 'batch.rb', batch_file_mode do |batch_file|
        RequireLoader.batch_file_created = true
        batch_file.puts "##{file_path}"
        ruby_code.lines.each do |line|
          next if line =~ /(\b|\.)require(\b|\()/
          batch_file.puts line
        end
      end
    end
  end

  def initialize(path)
    @path = path.sub(/\.rb\z/, '')
  end

  def load
    eval load_data(founded_path), self.class.binding
  end
  
  def founded_path
    all_pathes.find { |file_name| File.exist? file_name } || raise(LoadError)
  end

  def all_pathes
    ["#{@path}.rb"] + self.class.pathes.map do |path|
      File.join path, "#{@path}.rb"
    end
  end
end

if RequireLoader.enabled?
  include RequireLoader::ToInclude
  RequireLoader.binding = binding
end

class SideScriptsLoader
  class << self
    def load(dir)
      new(dir).load
    end

    def add_to_path(dir)
      new(dir).add_to_path
    end

    def add_gems_to_path
      if Dir.exist? 'gems'
        Dir.entries('gems').each do |entry|
          if Dir.exist? File.join('gems', entry)
            new(File.join 'gems', entry, 'lib').add_to_path
          end
        end
      end
    end
  end

  def initialize(dir)
    @dir = dir
  end

  def dirname
    RequireLoader.enabled? ? @dir : File.expand_path(@dir, Dir.pwd)
  end

  def load
    load_entries if Dir.exist? dirname
  end

  def add_to_path
    pathes << dirname if Dir.exist?(dirname) && !pathes.include?(dirname)
  end

  private

  def pathes
    RequireLoader.enabled? ? RequireLoader.pathes : $LOAD_PATH
  end

  def load_entries
    dir_entries = Dir.entries(dirname).delete_if{ |entry| entry=~/^\./ }
    if dir_entries.include?("load.cfg")
      load = load_config
      load.each do |entry|
        entry.gsub!(/[\n]$/){""}
        require filename(entry)
        dir_entries -= ["#{entry}.rb"]
      end
    end
    dir_entries.each do |entry|
      require filename(entry) if entry =~ /\.rb\Z/
    end
  end

  def load_config
    open(config, "r").readlines.delete_if{ |line| line =~ /^[\s]?#/ }
  end

  def config
    filename("load.cfg")
  end

  def filename(entry)
    joined = File.join dirname, entry
    RequireLoader.enabled? ? joined : File.expand_path(joined, Dir.pwd)
  end
end

class << Marshal
  alias side_script_load load
  def load(port, proc = nil)
    side_script_load(port, proc)  
  rescue TypeError => e
    if port.kind_of?(File) && File.extname(port.path) == ".rb"
      port.rewind 
      lines = port.lines.to_a.join
      RequireLoader.write_to_batch(lines, port.path) if RequireLoader.batch?
      lines
    else
      raise e
    end
  end
end 