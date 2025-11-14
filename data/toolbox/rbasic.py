import debugger
import constants
import format

def type_of(value):
	"""Get the Ruby type of a VALUE.
	
	Returns the RUBY_T_* constant value (e.g., RUBY_T_STRING, RUBY_T_ARRAY),
	or None if the type cannot be determined.
	"""
	basic = value.cast(constants.type_struct('struct RBasic').pointer())
	flags = int(basic.dereference()['flags'])
	RUBY_T_MASK = constants.type('RUBY_T_MASK')
	return flags & RUBY_T_MASK

def is_type(value, ruby_type_constant):
	"""Check if a VALUE is of a specific Ruby type.
	
	Arguments:
		value: The GDB value to check
		ruby_type_constant: String name of the constant (e.g., 'RUBY_T_STRING')
	
	Returns:
		True if the value is of the specified type, False otherwise
	"""
	type_flag = type_of(value)
	expected_type = constants.get(ruby_type_constant)
	return type_flag == expected_type

# Map of type constants to their names for display
TYPE_NAMES = {
	'RUBY_T_NONE': 'T_NONE',
	'RUBY_T_OBJECT': 'T_OBJECT',
	'RUBY_T_CLASS': 'T_CLASS',
	'RUBY_T_MODULE': 'T_MODULE',
	'RUBY_T_FLOAT': 'T_FLOAT',
	'RUBY_T_STRING': 'T_STRING',
	'RUBY_T_REGEXP': 'T_REGEXP',
	'RUBY_T_ARRAY': 'T_ARRAY',
	'RUBY_T_HASH': 'T_HASH',
	'RUBY_T_STRUCT': 'T_STRUCT',
	'RUBY_T_BIGNUM': 'T_BIGNUM',
	'RUBY_T_FILE': 'T_FILE',
	'RUBY_T_DATA': 'T_DATA',
	'RUBY_T_MATCH': 'T_MATCH',
	'RUBY_T_COMPLEX': 'T_COMPLEX',
	'RUBY_T_RATIONAL': 'T_RATIONAL',
	'RUBY_T_NIL': 'T_NIL',
	'RUBY_T_TRUE': 'T_TRUE',
	'RUBY_T_FALSE': 'T_FALSE',
	'RUBY_T_SYMBOL': 'T_SYMBOL',
	'RUBY_T_FIXNUM': 'T_FIXNUM',
	'RUBY_T_UNDEF': 'T_UNDEF',
	'RUBY_T_IMEMO': 'T_IMEMO',
	'RUBY_T_NODE': 'T_NODE',
	'RUBY_T_ICLASS': 'T_ICLASS',
	'RUBY_T_ZOMBIE': 'T_ZOMBIE',
}

def type_name(value):
	"""Get the human-readable type name for a VALUE.
	
	Returns:
		String like 'T_STRING', 'T_ARRAY', 'T_HASH', etc., or 'Unknown(0x...)'
	"""
	type_flag = type_of(value)
	
	# Try to find matching type name
	for const_name, display_name in TYPE_NAMES.items():
		if constants.get(const_name) == type_flag:
			return display_name
	
	return f'Unknown(0x{type_flag:x})'

class RBasic:
	"""Generic Ruby object wrapper for unhandled types.
	
	This provides a fallback for types that don't have specialized handlers.
	"""
	def __init__(self, value):
		self.value = value
		self.basic = value.cast(constants.type_struct('struct RBasic').pointer())
		self.flags = int(self.basic.dereference()['flags'])
		self.type_flag = self.flags & constants.type('RUBY_T_MASK')
	
	def __str__(self):
		type_str = type_name(self.value)
		return f"<{type_str}@0x{int(self.value):x}>"
	
	def print_to(self, terminal):
		"""Print formatted basic object representation."""
		type_str = type_name(self.value)
		addr = int(self.value)
		# Use print_type_tag for consistency with other types
		terminal.print_type_tag(type_str, addr)
	
	def print_recursive(self, printer, depth):
		"""Print this basic object (no recursion)."""
		printer.print(self)
