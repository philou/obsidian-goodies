#!/bin/usr/ruby

require 'pathname'
require 'time'
require 'fileutils'
require 'optparse'

class Parser
    def self.parse(args)
        options = {
            # Files to exclude
            file_exclusions: [/Indexes/],
        
            # Tags to exclude
            tag_exclusions: [
                /coachingPainCause\/.*/,
                /coachingPhase\/.*/,
                /emotion\/.*/,
                /pain/,
                /30x500/,
                /techAgileCoaching/ ],
        
            # "Most" used or "Least" used?
            extreme: "Most",
            
            # Keep only the most used tags
            limit: 5,
        
            # Verbose mode on
            verbose: false
        }
            
        opt_parser = OptionParser.new do |opts|
            opts.banner = "Counts tags in directory.\nUsage: count_tags.rb [options] DIRECTORY"

            opts.on("-f", "--excluse-files r1,r2,...", Array, "Comma separated list of regex for files to exclude. Defaults to #{options[:file_exclusions]}") do |v|
                options[:file_exclusions] = v
            end
            opts.on("-t", "--exclude-tags r1,r2,...", Array, "Comma separated list of regex for tags to exclude. Default to #{options[:tag_exclusions]}") do |v|
                options[:tag_exclusions] = v
            end
            opts.on("-r", "--reverse", "By default, prints the most used tags. Switch this flag on to print the least used instead.") do |v|
                options[:extreme] = "Least"
            end
            opts.on("-l", "--limit N", Integer, "Print only N tags, default to #{options[:limit]}.") do |v|
                options[:limit] = v
            end

            opts.on("-v", "--verbose", "Run verbosely, for the moment only prints the arguments") do
                options[:verbose] = true
            end
            opts.on("-h", "--help", "Prints this help") do
                puts opts
                exit
            end
        end
        
        opt_parser.parse!(args)
        return options
    end
end

def first_or_last(options)
    if options[:extreme] == "Most"
        :first
    else
        :last
    end
end

def excluded?(item, regexps)
    regexps.any? {|exclusion_regex| exclusion_regex =~ item}
end
    
def excluded_tag?(tag, options)
    excluded?(tag, options[:tag_exclusions])
end

def excluded_file?(file_name, options)
    excluded?(file_name.basename.to_s, options[:file_exclusions])
end

begin
    options = Parser.parse ARGV

    if options[:verbose]
        puts "Running with options:"
        pp options
        puts
        puts "Remaining arguments:"
        pp ARGV
    end
    
    if ARGV.empty?
        Parser.parse %w[--help]
        exit 1
    end
        
    directory_path = Pathname.new(ARGV[0])

    tag_counts = Hash.new(0)

    notes = directory_path.children(false)
        .filter {|file_name| not excluded_file?(file_name, options) }
        .map {|file_name| directory_path.join(file_name) }.to_a

    notes.each do |note_path|
        markdown = note_path.read
        tags = markdown.scan(/ #[^\s]+/).map {|s| s[2..-1]}
        tags.each do |tag|
            tag_counts[tag] += 1
        end
    end

    sorted_tags = tag_counts.sort_by {|k,v| v}.reverse

    puts "#{options[:extreme]} used tags in `#{directory_path}`"
    puts
    sorted_tags
        .filter {|tag, count| not excluded_tag?(tag, options) }
        .send(first_or_last(options), options[:limit])
        .each do |tag, count|
            puts "## ##{tag}: #{count} time(s)"
            puts
            puts "```expander"
            puts "tag:\##{tag} path:\"#{directory_path}\""
            puts "```"
            puts
        end

rescue StandardError => e
    STDERR.puts "-- ERROR: Could not process #{directory_path.to_s}"
    STDERR.puts e.message
    STDERR.puts 
    STDERR.puts "\tat #{e.backtrace.join("\n\tat ")}"
end
  