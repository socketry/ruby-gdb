# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

GC.start
GC.compact

fiber = Fiber.new do
	puts "Fiber created"
end

fiber.resume
