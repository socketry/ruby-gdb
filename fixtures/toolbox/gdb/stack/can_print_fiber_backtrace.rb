# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def fiber_inner_method
	puts "In fiber inner method"
end

def fiber_middle_method
	fiber_inner_method
end

fiber = Fiber.new do
	fiber_middle_method
end

# Resume the fiber
fiber.resume
