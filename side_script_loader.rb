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
  end

  def initialize(path)
    @path = path.sub(/\.rb\z/, '')
  end

  def load
    File.open founded_path do |file|
      lines = file.lines.to_a.join
      write_to_batch lines if RequireLoader.batch?
      eval lines, self.class.binding
    end
  end

  def write_to_batch(ruby_code)
    File.open 'batch.rb', batch_file_mode do |batch_file|
      RequireLoader.batch_file_created = true
      batch_file.puts "##{founded_path}"
      ruby_code.lines.each do |line|
        next if line =~ /(\b|\.)require(\b|\()/
        batch_file.puts line
      end
    end
  end

  def batch_file_mode
    self.class.batch_file_created? ? 'a' : 'w'
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
    Dir.entries(dirname).each do |entry|
      require filename(entry) if entry =~ /\.rb\Z/
    end
  end

  def filename(entry)
    joined = File.join dirname, entry
    RequireLoader.enabled? ? joined : File.expand_path(joined, Dir.pwd)
  end
end