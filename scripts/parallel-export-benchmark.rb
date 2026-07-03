#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "set"
require "shellwords"
require "time"

options = {
  jobs: 2,
  output: nil,
  runner: ["swift", "run", "RunningOverlay"],
  skip_serial: false,
  prepare_only: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: scripts/parallel-export-benchmark.rb SNAPSHOT.json [options]"

  opts.on("-j", "--jobs N", Integer, "Number of parallel exporter processes. Default: 2") do |value|
    options[:jobs] = [value, 1].max
  end

  opts.on("-o", "--output DIR", "Benchmark output directory.") do |value|
    options[:output] = value
  end

  opts.on("--runner COMMAND", "Exporter command. Default: swift run RunningOverlay") do |value|
    options[:runner] = Shellwords.split(value)
  end

  opts.on("--skip-serial", "Only run the parallel benchmark.") do
    options[:skip_serial] = true
  end

  opts.on("--prepare-only", "Write shard snapshots and summary without running exports.") do
    options[:prepare_only] = true
  end
end

parser.parse!
snapshot_path = ARGV.shift

unless snapshot_path
  warn parser
  exit 64
end

snapshot_path = File.expand_path(snapshot_path)
unless File.file?(snapshot_path)
  warn "Snapshot not found: #{snapshot_path}"
  exit 66
end

started_at = Time.now
stamp = started_at.utc.strftime("%Y%m%d_%H%M%S")
output_root = File.expand_path(options[:output] || "parallel_export_benchmark_#{stamp}")
FileUtils.mkdir_p(output_root)

snapshot = JSON.parse(File.read(snapshot_path))
media_ids = (snapshot.fetch("mediaItems", []) || []).map { |item| item["id"] }.compact.to_set
tracks = snapshot.fetch("timeline").fetch("tracks")

clips = []
tracks.each_with_index do |track, track_index|
  (track["clips"] || []).each_with_index do |clip, clip_index|
    media_item_id = clip["mediaItemID"]
    next if media_item_id.nil? || !media_ids.include?(media_item_id)

    clips << {
      track_index: track_index,
      clip_index: clip_index,
      duration: clip["duration"].to_f,
      name: clip["sourceFileName"] || media_item_id
    }
  end
end

if clips.empty?
  warn "Snapshot does not contain exportable timeline clips."
  exit 65
end

job_count = [options[:jobs], clips.length].min
shards = Array.new(job_count) { { duration: 0.0, clips: [] } }

clips.sort_by { |clip| [-clip[:duration], clip[:track_index], clip[:clip_index]] }.each do |clip|
  shard = shards.min_by { |candidate| [candidate[:duration], candidate[:clips].length] }
  shard[:clips] << clip
  shard[:duration] += clip[:duration]
end

def deep_copy(value)
  Marshal.load(Marshal.dump(value))
end

def write_shard_snapshot(snapshot, shard, path)
  next_snapshot = deep_copy(snapshot)
  keep = {}
  shard[:clips].each do |clip|
    keep[[clip[:track_index], clip[:clip_index]]] = true
  end

  next_snapshot.fetch("timeline").fetch("tracks").each_with_index do |track, track_index|
    filtered_clips = []
    (track["clips"] || []).each_with_index do |clip, clip_index|
      filtered_clips << clip if keep[[track_index, clip_index]]
    end
    track["clips"] = filtered_clips
  end

  File.write(path, JSON.pretty_generate(next_snapshot))
end

def newest_profile(directory)
  profiles = Dir.glob(File.join(directory, "export_profile_*.json"))
  return nil if profiles.empty?

  profiles.max_by { |path| File.mtime(path) }
end

def profile_summary(directory)
  path = newest_profile(directory)
  return {} unless path && File.file?(path)

  profile = JSON.parse(File.read(path))
  {
    "profile" => path,
    "totalDuration" => profile["totalDuration"],
    "imageRenderDuration" => profile["imageRenderDuration"],
    "pixelBufferDrawDuration" => profile["pixelBufferDrawDuration"],
    "appendDuration" => profile["appendDuration"],
    "writerWaitDuration" => profile["writerWaitDuration"],
    "renderedFrameCount" => profile["renderedFrameCount"],
    "reusedFrameCount" => profile["reusedFrameCount"],
    "segmentCount" => profile["segmentCount"]
  }
rescue JSON::ParserError
  {}
end

def run_export(label, runner, snapshot, output_dir, log_path)
  FileUtils.mkdir_p(output_dir)
  command = runner + ["--benchmark-export", snapshot, "--benchmark-output", output_dir]
  started = Time.now
  pid = Process.spawn(*command, out: log_path, err: [:child, :out])
  _, status = Process.wait2(pid)
  {
    label: label,
    command: command.join(" "),
    output: output_dir,
    log: log_path,
    wallClock: Time.now - started,
    success: status.success?,
    exitStatus: status.exitstatus
  }
end

shard_dir = File.join(output_root, "shards")
FileUtils.mkdir_p(shard_dir)
shard_paths = shards.each_with_index.map do |shard, index|
  path = File.join(shard_dir, "worker_#{index + 1}.json")
  write_shard_snapshot(snapshot, shard, path)
  path
end

results = {
  "snapshot" => snapshot_path,
  "jobsRequested" => options[:jobs],
  "jobsUsed" => job_count,
  "clipCount" => clips.length,
  "totalClipDuration" => clips.sum { |clip| clip[:duration] },
  "shards" => shards.each_with_index.map do |shard, index|
    {
      "index" => index + 1,
      "snapshot" => shard_paths[index],
      "clipCount" => shard[:clips].length,
      "duration" => shard[:duration],
      "clips" => shard[:clips].map { |clip| { "track" => clip[:track_index], "clip" => clip[:clip_index], "duration" => clip[:duration], "name" => clip[:name] } }
    }
  end
}

unless options[:prepare_only]
  unless options[:skip_serial]
    serial_output = File.join(output_root, "serial")
    serial_log = File.join(output_root, "serial.log")
    puts "[ParallelExportBenchmark] serial baseline -> #{serial_output}"
    serial = run_export("serial", options[:runner], snapshot_path, serial_output, serial_log)
    serial.merge!(profile_summary(serial_output))
    results["serial"] = serial
    unless serial[:success]
      File.write(File.join(output_root, "benchmark_summary.json"), JSON.pretty_generate(results))
      warn "Serial export failed. See #{serial_log}"
      exit serial[:exitStatus] || 1
    end
  end

  parallel_dir = File.join(output_root, "parallel")
  FileUtils.mkdir_p(parallel_dir)
  puts "[ParallelExportBenchmark] parallel workers=#{job_count} -> #{parallel_dir}"
  parallel_started = Time.now
  running = shards.each_with_index.map do |_shard, index|
    worker_output = File.join(parallel_dir, "worker_#{index + 1}")
    worker_log = File.join(output_root, "worker_#{index + 1}.log")
    command = options[:runner] + ["--benchmark-export", shard_paths[index], "--benchmark-output", worker_output]
    started = Time.now
    pid = Process.spawn(*command, out: worker_log, err: [:child, :out])
    {
      label: "worker_#{index + 1}",
      pid: pid,
      command: command.join(" "),
      output: worker_output,
      log: worker_log,
      started: started
    }
  end

  workers = running.map do |worker|
    _, status = Process.wait2(worker[:pid])
    result = {
      label: worker[:label],
      command: worker[:command],
      output: worker[:output],
      log: worker[:log],
      wallClock: Time.now - worker[:started],
      success: status.success?,
      exitStatus: status.exitstatus
    }
    result.merge!(profile_summary(worker[:output]))
    result
  end
  parallel_wall = Time.now - parallel_started
  results["parallel"] = {
    "wallClock" => parallel_wall,
    "workers" => workers
  }

  failed = workers.reject { |worker| worker[:success] }
  unless failed.empty?
    File.write(File.join(output_root, "benchmark_summary.json"), JSON.pretty_generate(results))
    warn "Parallel export failed for: #{failed.map { |worker| worker[:label] }.join(", ")}"
    exit 1
  end
end

if results["serial"] && results["parallel"]
  serial_wall = results["serial"][:wallClock]
  parallel_wall = results["parallel"]["wallClock"]
  results["speedup"] = serial_wall.positive? ? serial_wall / parallel_wall : nil
end

results["wallClock"] = Time.now - started_at
summary_json = File.join(output_root, "benchmark_summary.json")
summary_txt = File.join(output_root, "benchmark_summary.txt")
File.write(summary_json, JSON.pretty_generate(results))

lines = []
lines << "Parallel Export Benchmark"
lines << "========================="
lines << "Snapshot: #{snapshot_path}"
lines << "Output: #{output_root}"
lines << "Clips: #{results["clipCount"]}"
lines << "Jobs: #{results["jobsUsed"]}"
lines << ""
results["shards"].each do |shard|
  lines << "Worker #{shard["index"]}: clips=#{shard["clipCount"]} duration=#{format("%.2f", shard["duration"])}s"
end
if results["serial"]
  lines << ""
  lines << "Serial wall-clock: #{format("%.3f", results["serial"][:wallClock])}s"
end
if results["parallel"]
  lines << "Parallel wall-clock: #{format("%.3f", results["parallel"]["wallClock"])}s"
end
if results["speedup"]
  lines << "Speedup: #{format("%.2f", results["speedup"])}x"
end
lines << ""
lines << "JSON summary: #{summary_json}"
File.write(summary_txt, lines.join("\n") + "\n")

puts lines.join("\n")
