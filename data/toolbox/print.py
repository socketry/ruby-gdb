"""Object inspection command for Ruby values."""

import debugger
import sys

print("DEBUG: inspect.py is being loaded", file=sys.stderr)

# Import utilities
import command
import constants
import value
import rstring
import rarray
import rhash
import rsymbol
import rstruct
import rfloat
import rbignum
import rbasic
import format

print("DEBUG: All imports done in inspect.py", file=sys.stderr)


class RubyObjectPrinter:
	"""Print Ruby objects with recursive descent into nested structures."""
	
	USAGE = command.Usage(
		summary="Print Ruby objects with recursive inspection",
		parameters=[('value', 'VALUE or expression to print')],
		options={
			'depth': (int, 1, 'Maximum recursion depth for nested objects')
		},
		flags=[
			('debug', 'Show internal structure and debug information')
		],
		examples=[
			("rb-inspect $errinfo", "Print exception object"),
			("rb-inspect $ec->storage --depth 3", "Print fiber storage with depth 3"),
			("rb-inspect $ec->cfp->sp[-1] --debug", "Print top of stack with debug info")
		]
	)
	
	def invoke(self, arguments, terminal, from_tty):
		"""Execute the inspect command.
		
		Args:
			arguments: Parsed Arguments object
			terminal: Terminal formatter
			from_tty: True if called from TTY
		"""
		# Get options
		max_depth = arguments.get_option('depth', 1)
		debug_mode = arguments.has_flag('debug')
		
		# Validate depth
		if max_depth < 1:
			print("Error: --depth must be >= 1")
			return
		
		# Create printer
		printer = format.Printer(terminal, max_depth, debug_mode)
		
		# Process each expression
		for expression in arguments.expressions:
			try:
				# Evaluate the expression
				ruby_value = debugger.parse_and_eval(expression)
				
				# Interpret the value and let it print itself recursively
				ruby_object = value.interpret(ruby_value)
				ruby_object.print_recursive(printer, max_depth)
			except debugger.Error as e:
				print(f"Error evaluating expression '{expression}': {e}")
			except Exception as e:
				print(f"Error processing '{expression}': {type(e).__name__}: {e}")
				if debug_mode:
					import traceback
					traceback.print_exc(file=sys.stderr)


print("DEBUG: RubyObjectPrinter class defined", file=sys.stderr)

# Register command using new interface
print("DEBUG: About to register rb-inspect", file=sys.stderr)
try:
	print(f"DEBUG: Registering rb-inspect, debugger.register = {debugger.register}", file=sys.stderr)
	result = debugger.register("rb-inspect", RubyObjectPrinter, usage=RubyObjectPrinter.USAGE)
	print(f"DEBUG: Registration result = {result}", file=sys.stderr)
except Exception as e:
	print(f"ERROR: Failed to register rb-inspect: {e}", file=sys.stderr)
	import traceback
	traceback.print_exc(file=sys.stderr)

