# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/shared"
require "open3"

module Toolbox
	# Discover test cases from a subdirectory
	# @param subdir [String] Subdirectory name (e.g., "object", "fiber", "heap")
	# @yield [name, test_case] Block to call for each test case
	def self.test_cases(path, extension)
		# Expand path relative to the fixtures directory:
		path = File.expand_path(path, __dir__)
		
		Dir.glob(extension, base: path).each do |relative_path|
			base_name = File.basename(relative_path, File.extname(relative_path))
			name = base_name.gsub("_", " ")
			
			input_path = File.join(path, relative_path)
			script_path = File.join(path, "#{base_name}.rb")
			output_path = File.join(path, "#{base_name}.txt")
			
			test_case = {
				name: base_name,
				input_path: input_path,
				script_path: File.exist?(script_path) ? script_path : nil,
				output_path: output_path
			}
			
			yield name, test_case
		end
	end
	
	TestCases = Sus::Shared("test cases") do |path, extension|
		def update_output?(test_case)
			if ENV["TOOLBOX_UPDATE_OUTPUT"] == "1"
				return true
			end
			
			unless File.exist?(test_case[:output_path])
				return true
			end
			
			return false
		end
		
		# Normalize debugger output by extracting content between markers
		# and removing non-deterministic values
		# @param output [String] Raw output from debugger
		# @return [String] Normalized output
		def normalize_output(output)
			# Extract content between markers if present
			if output =~ /===TOOLBOX-OUTPUT-START===\n(.*?\n)===TOOLBOX-OUTPUT-END===/m
				output = $1
			end
			
			# Apply broad normalizations to the whole text first
			output = normalize_addresses(output)
			output = normalize_type_tags(output)
			output = normalize_strings(output)
			output = normalize_paths(output)
			
			return output
		end
		
		def normalize_paths(text)
			root = File.expand_path("../..", __dir__)
			text.gsub!(root, "[...]")
			text
		end
		
		# Normalize addresses in output
		# @param text [String] Text to normalize
		# @return [String] Normalized text
		def normalize_addresses(text)
			# Normalize type tags with addresses: <T_TYPE@0xABCD details> -> <T_TYPE@...>
			text = text.gsub(/<(T_\w+)@0x[0-9a-f]+([^>]*)>/, '<\1@...>')
			
			# Normalize C type pointers: <void *@0xABCD details> -> <void *@...>
			text = text.gsub(/<([A-Za-z_][\w\s*]+?)@0x[0-9a-f]+([^>]*)>/, '<\1@...>')
			
			# Normalize anonymous class references: #<Class:0xABCD> -> #<Class:0x...>
			text = text.gsub(/#<([A-Z][A-Za-z0-9_:]*):0x[0-9a-f]+>/, '#<\1:0x...>')
			
			# Normalize Ruby class instances: <ClassName:0xABCD> -> <ClassName:0x...>
			text = text.gsub(/<([A-Z][A-Za-z0-9_:]*):0x[0-9a-f]+>/, '<\1:0x...>')
			
			# Normalize hex addresses: 0x123ABC -> 0x...
			text = text.gsub(/\b0x[0-9a-f]+\b/i, "0x...")
			
			# Normalize plain hex in angle brackets: <0xABCD> -> <0x...>
			text = text.gsub(/<0x[0-9a-f]+>/i, "<0x...>")
			
			# Normalize process IDs: "Process 12345" -> "Process <PID>"
			text = text.gsub(/Process \d+ (launched|stopped|exited)/, 'Process <PID> \1')
			
			return text
		end
		
		# Normalize type tags in output
		# @param text [String] Text to normalize
		# @return [String] Normalized text
		def normalize_type_tags(text)
			# Normalize plain numbers in angle brackets: <12345> -> <...>
			text = text.gsub(/<\d+>/, "<...>")
			
			return text
		end
		
		# Normalize strings in output
		# @param text [String] Text to normalize
		# @return [String] Normalized text
		def normalize_strings(text)
			# Normalize string content (including escaped quotes)
			# (?:\\.|[^"]) matches either escaped character or non-quote
			text = text.gsub(/"((?:\\.|[^"])*)"/, '"..."')
			text = text.gsub(/'((?:\\.|[^'])*)'/, '"..."')
			text = text.gsub(/CREATED|RESUMED|SUSPENDED|TERMINATED/, "[state]")
			
			return text
		end
		
		Toolbox.test_cases(path, extension) do |name, test_case|
			it name, unique: test_case[:name] do
				output, status = run_test_case(test_case)
				
				expect(status).to be(:success?)
				
				output = normalize_output(output)
				
				if update_output?(test_case)
					File.write(test_case[:output_path], output)
				else
					expected_output = File.readlines(test_case[:output_path])
					output.each_line.with_index do |line, index|
						expect(line).to be == expected_output[index]
					end
				end
			end
		end
	end
end