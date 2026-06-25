#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "uri"

root = Pathname.new(__dir__).parent
failures = []

markdown_files = IO.popen(
  ["git", "-C", root.to_s, "ls-files", "-z", "--cached", "--others", "--exclude-standard", "*.md"],
  &:read
).split("\0").sort

markdown_files.each do |relative_file|
  source = root.join(relative_file)
  next unless source.file?

  content = source.read

  content.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |raw_target|
    target = raw_target.strip
    next if target.empty?
    next if target.start_with?("#", "http://", "https://", "mailto:")

    path = target.split("#", 2).first
    path = path.split(/\s+["']/, 2).first
    path = URI.decode_www_form_component(path)
    resolved = source.dirname.join(path).cleanpath

    failures << "#{source.relative_path_from(root)} -> #{target}" unless resolved.exist?
  rescue ArgumentError
    failures << "#{source.relative_path_from(root)} -> invalid URL encoding: #{target}"
  end
end

unless failures.empty?
  warn "Broken local Markdown links:"
  failures.each { |failure| warn "  #{failure}" }
  exit 1
end

puts "Markdown link check passed."
