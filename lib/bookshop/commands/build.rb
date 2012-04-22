require 'thor/group'
require 'erb'
require 'fileutils'
require 'yaml'

require 'bookshop/commands/yaml/book'

module Bookshop
  module Commands

    # Define build commands for bookshop command line
    class Build < Thor::Group
      include Thor::Actions
      
      BOOK_SOURCE = 'book.html.erb'
      
      def initialize
        @book = []
      end
      
      ARGV << '--help' if ARGV.empty?

      aliases = {
        "p"  => "pdf"
      }

      build = ARGV.shift
      build = aliases[build] || build
      

      # Define arguments and options
      argument :type
      class_option :test_framework, :default => :test_unit

      # Define source root of application
      def self.source_root
        File.dirname(__FILE__)
      end

      # Load YAML files
      def self.load_yaml_files
        # Load the book.yml into the Book object
        @book = Book.new(YAML.load_file('config/book.yml'))
        # @toc = Toc.new(YAML.load_file('config/toc.yml'))
      end

      # Renders <%= import(source.html.erb) %> files with ERB
      # 
      # When a new import() is encountered within source files it is
      #    processed with this method and the result is added to 'erb'
      def self.import(file)
        load_yaml_files
        # Parse the source erb file
        ERB.new(File.read('book/'+file)).result(binding).gsub(/\n$/,'')
      end

      case build
      
      # 'build html' generates a html version of the book from the
      #    book/book.html.erb source file
      # @output variable is set to "html" for access as a conditional
      #   in the source erb's
      when 'html'
        # Clean up any old builds
        puts "Deleting any old builds"
        FileUtils.rm_r Dir.glob('builds/html/*')
        
        @output = :html
        erb = import(BOOK_SOURCE)
        puts "Generating new html from erb"
        File.open("builds/html/book.html", 'a') do |f|
          f << erb
        end
        
        FileUtils.cp_r('book/assets/', 'builds/html/', :verbose => true)
        
      when 'epub'
        # Clean up any old builds
        puts "Deleting any old builds"
        FileUtils.rm_r Dir.glob('builds/epub/*')

        @output = :epub

        FileUtils.cp_r('book/epub/META-INF', 'builds/epub/', :verbose => true)
        FileUtils.mkdir 'builds/epub/OEBPS'
        FileUtils.cp_r('book/epub/mimetype', 'builds/epub/', :verbose => true)
        
        erb = import(BOOK_SOURCE)
        puts "Generating new html from erb"
        File.open("builds/epub/OEBPS/book.html", 'a') do |f|
          f << erb
        end
        
        # Generate the cover.html file
        opf = import("frontmatter/cover.html.erb")
        puts "Generating new cover.html from erb"
        File.open("builds/epub/OEBPS/cover.html", 'a') do |f|
          f << opf
        end
        
        # Generate the nav.html file
        opf = import("frontmatter/toc.html.erb")
        puts "Generating new toc.html from erb"
        File.open("builds/epub/OEBPS/toc.html", 'a') do |f|
          f << opf
        end

        # Generate the OPF file
        opf = import("epub/OEBPS/content.opf.erb")
        puts "Generating new content.opf from erb"
        File.open("builds/epub/OEBPS/content.opf", 'a') do |f|
          f << opf
        end
        
        # Generate the NCX file
        ncx = import("epub/OEBPS/toc.ncx.erb")
        puts "Generating new toc.ncx from erb"
        File.open("builds/epub/OEBPS/toc.ncx", 'a') do |f|
          f << ncx
        end
        
        FileUtils.cp_r 'book/assets', 'builds/epub/OEBPS/assets/', :verbose => true
        FileUtils.rm %w( builds/epub/OEBPS/assets/css/stylesheet.pdf.css
                         builds/epub/OEBPS/assets/css/stylesheet.html.css
                         builds/epub/OEBPS/assets/css/stylesheet.mobi.css )
        
        puts "Zipping up into epub"
        cmd = %x[cd builds/epub/ && zip -X0 "book.epub" mimetype && zip -rDX9 "book.epub" * -x "*.DS_Store" -x mimetype]
        
        puts "Validating with epubcheck"
        cmd  = cmd = system("java -jar script/epubcheck/epubcheck.jar builds/epub/book.epub")
        
      when 'mobi'
        # Clean up any old builds
        puts "Deleting any old builds"
        FileUtils.rm_r Dir.glob('builds/mobi/*')

        @output = :mobi

        FileUtils.cp_r('book/epub/META-INF', 'builds/mobi/', :verbose => true)
        FileUtils.mkdir 'builds/mobi/OEBPS'
        FileUtils.cp_r('book/epub/mimetype', 'builds/mobi/', :verbose => true)
        
        erb = import(BOOK_SOURCE)
        puts "Generating new html from erb"
        File.open("builds/mobi/OEBPS/book.html", 'a') do |f|
          f << erb
        end
        
        # Generate the cover.html file
        opf = import("frontmatter/cover.html.erb")
        puts "Generating new cover.html from erb"
        File.open("builds/mobi/OEBPS/cover.html", 'a') do |f|
          f << opf
        end
        
        # Generate the nav.html file
        opf = import("frontmatter/toc.html.erb")
        puts "Generating new toc.html from erb"
        File.open("builds/mobi/OEBPS/toc.html", 'a') do |f|
          f << opf
        end

        # Generate the OPF file
        opf = import("epub/OEBPS/content.opf.erb")
        puts "Generating new content.opf from erb"
        File.open("builds/mobi/OEBPS/content.opf", 'a') do |f|
          f << opf
        end
        
        # Generate the NCX file
        ncx = import("epub/OEBPS/toc.ncx.erb")
        puts "Generating new toc.ncx from erb"
        File.open("builds/mobi/OEBPS/toc.ncx", 'a') do |f|
          f << ncx
        end
        
        FileUtils.cp_r 'book/assets', 'builds/mobi/OEBPS/assets/', :verbose => true
        FileUtils.rm %w( builds/mobi/OEBPS/assets/css/stylesheet.pdf.css
                         builds/mobi/OEBPS/assets/css/stylesheet.html.css
                         builds/mobi/OEBPS/assets/css/stylesheet.epub.css )
        
        puts "Zipping up into epub"
        cmd = %x[cd builds/mobi/ && zip -X0 "book.epub" mimetype && zip -rDX9 "book.epub" * -x "*.DS_Store" -x mimetype]
        
        puts "Validating with epubcheck"
        
        # using exec so we can return the command results back to the terminal output
        cmd  = system("java -jar script/epubcheck/epubcheck.jar builds/mobi/book.epub")
        
        puts "Generating mobi file with KindleGen"
        if RUBY_PLATFORM =~ /linux/
          cmd = system("script/kindlegen/kindlegen_linux builds/mobi/book.epub")
        elsif RUBY_PLATFORM =~ /darwin/
          cmd = system("script/kindlegen/kindlegen_mac builds/mobi/book.epub")
        elsif RUBY_PLATFORM =~ /mswin32/
          cmd = system("script/kindlegen/kindlegen.exe builds/mobi/book.epub")
        else
          raise "We can't seem to execute the version of kindle specific to your platform."
        end
        
      # 'build pdf' generates a pdf version of the book from the builds/html/book.html
      #    which is generated from the book/book.html.erb source file
      when 'pdf'
        
        # Clean up any old builds
        puts "Deleting any old builds"
        FileUtils.rm_r Dir.glob('builds/pdf/*')
        
        @output = :pdf
        erb = import(BOOK_SOURCE)
        # Generate the html from ERB
        puts "Generating new html from erb"
        File.open('builds/pdf/book.html', 'a') do |f|
          f << erb
        end

        # Copy over html assets
        FileUtils.cp_r('book/assets/', 'builds/pdf/', :verbose => true)


        # Builds the pdf from builds/html/book.html
        puts "Building new pdf at builds/pdf/book.pdf from new html build"
        cmd = system("prince -v builds/pdf/book.html -o builds/pdf/book.pdf")

      else
        puts "Error: Command not recognized" unless %w(-h --help).include?(build)
        puts <<-EOT
      Usage: bookshop build [ARGS]

      The most common build commands are:
       pdf          Builds a new pdf  at /builds/pdf/book.pdf
       html         Builds a new html at /builds/html/book.html
       epub         Builds a new epub at /builds/epub/book.epub
       mobi         Builds a new mobi at /builds/mobi/book.mobi

      All commands can be run with -h for more information.
        EOT
      end
    end
  end
end
