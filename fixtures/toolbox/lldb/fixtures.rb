# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "fileutils"
require "open3"
require_relative "../debugger"

module Toolbox
	module LLDB
		module Fixtures
			include Toolbox::Debugger::Fixtures
			# Discover test cases from a subdirectory
			# @param subdir [String] Subdirectory name (e.g., "object", "fiber", "heap")
			# @yield [name, test_case] Block to call for each test case
			def self.test_cases(subdir)
				fixtures_dir = File.expand_path("../../../fixtures/toolbox/lldb/#{subdir}", __dir__)
				return unless Dir.exist?(fixtures_dir)
				
				# Find all .lldb script files
				Dir.glob(File.join(fixtures_dir, "*.lldb")).sort.each do |lldb_script|
					base_name = File.basename(lldb_script, ".lldb")
					
					# Expected .txt snapshot file
					txt_file = lldb_script.sub(/\.lldb$/, ".txt")
					
					# Optional .rb Ruby script (for setting up test state)
					rb_file = lldb_script.sub(/\.lldb$/, ".rb")
					rb_file = File.exist?(rb_file) ? rb_file : nil
					
					test_case = {
						name: "#{subdir}/#{base_name}",
						lldb_script: lldb_script,
						ruby_script: rb_file,
						snapshot_file: txt_file
					}
					
					yield base_name, test_case
				end
			end
			
			# Execute a test case (implements Debugger::Fixtures interface)
			# @param test_case [Hash] Test case configuration
			# @return [Hash] Result with :output and :raw_output
			def execute_test(test_case)
				lldb_script = test_case[:lldb_script]
				ruby_script = test_case[:ruby_script]
				
				# If there's a Ruby script, run it with LLDB
				if ruby_script
					result = run_ruby_with_lldb(ruby_script, lldb_script)
				else
					# Just run the LLDB script
					result = run_lldb_script(lldb_script)
				end
				
				# Apply LLDB-specific output filtering and normalization
				output = filter_lldb_prompts(result[:raw_output])
				output = normalize_output(output, debugger_prompts: lldb_prompt_patterns)
				
				{
					output: output,
					raw_output: result[:raw_output],
					status: result[:status]
				}
			end
			
			# LLDB-specific prompt patterns to filter out
			# @return [Array<Regexp>] Array of regex patterns
			def lldb_prompt_patterns
				[
					/^\(lldb\) target create/,
					/^Current executable set to/,
					/^\(lldb\) settings set/,
					/^\(lldb\) process launch/,
					/^Process \d+ launched:/,
					/^Process \d+ exited/,
					/^\(lldb\) quit/,
					/^Quitting LLDB will/,
					/^\(lldb\) command script import/,
					/^\(lldb\) rb-/
				]
			end
			
			# Filter LLDB-specific prompts from output
			# @param output [String] Raw output
			# @return [String] Filtered output
			def filter_lldb_prompts(output)
				lines = output.lines
				filtered = []
				
				lines.each do |line|
					# Skip LLDB prompts
					next if line.match?(/^\(lldb\)\s*$/)
					
					# Remove (lldb) prefix from command output lines
					line = line.sub(/^\(lldb\)\s+/, "")
					
					# Remove ANSI color codes
					line = line.gsub(/\e\[\d+m/, "")
					
					filtered << line
				end
				
				filtered.join
			end
			
			private
			
			# Run a Ruby script under LLDB with an LLDB script
			def run_ruby_with_lldb(ruby_script, lldb_script)
				# Run LLDB in batch mode, loading ruby as target
				# The LLDB script is expected to set up breakpoints and run
				cmd = ["lldb", "--batch", "--source", lldb_script, "--source-quietly", "ruby", "--", ruby_script]
				
				stdout, status = Open3.capture2(*cmd)
				
				{raw_output: stdout, status: status}
			end
			
			# Run an LLDB script directly (no Ruby process)
			def run_lldb_script(lldb_script)
				# Run LLDB in batch mode with the script
				cmd = ["lldb", "--batch", "--source", lldb_script, "--source-quietly"]
				
				stdout, status = Open3.capture2(*cmd)
				
				{raw_output: stdout, status: status}
			end
		end
	end
end
