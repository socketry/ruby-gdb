# Object Inspection

This guide explains how to use `rb-inspect` to inspect Ruby objects, hashes, arrays, and structs in GDB.

## Why Object Inspection Matters

When debugging Ruby programs or analyzing core dumps, you often need to inspect complex data structures that are difficult to read in their raw memory representation. Standard GDB commands show pointer addresses and raw memory, but not the logical structure of Ruby objects.

Use `rb-inspect` when you need:

- **Understand exception objects**: See the full exception hierarchy, message, and backtrace data
- **Inspect fiber storage**: View thread-local data and fiber-specific variables
- **Debug data corruption**: Check the contents of hashes and arrays for unexpected values
- **Analyze VM state**: Examine objects on the VM stack without manual pointer arithmetic

## Basic Usage

The `rb-inspect` command recursively prints Ruby objects in a human-readable format.

### Syntax

~~~
rb-inspect <expression> [--depth N] [--debug]
~~~

Where:
- `<expression>`: Any GDB expression that evaluates to a Ruby VALUE
- `--depth N`: Maximum recursion depth (default: 1)
- `--debug`: Enable diagnostic output for troubleshooting

### Simple Values

Print immediate values and special constants:

~~~
(gdb) rb-inspect 0        # <T_FALSE>
(gdb) rb-inspect 8        # <T_NIL>
(gdb) rb-inspect 20       # <T_TRUE>
(gdb) rb-inspect 85       # <T_FIXNUM> 42
~~~

These work without any Ruby process running, making them useful for learning and testing.

### Expressions

Use any valid GDB expression:

~~~
(gdb) rb-inspect $ec->errinfo                    # Exception object
(gdb) rb-inspect $ec->cfp->sp[-1]                # Top of VM stack
(gdb) rb-inspect $ec->storage                    # Fiber storage hash
(gdb) rb-inspect (VALUE)0x00007f8a12345678      # Object at specific address
~~~

## Inspecting Hashes

Ruby hashes have two internal representations (ST table and AR table). The command automatically detects and displays both:

### Small Hashes (AR Table)

For hashes with fewer than 8 entries, Ruby uses an array-based implementation:

~~~
(gdb) rb-inspect $some_hash
<T_HASH@...>
[   0] K: <T_SYMBOL> :name
       V: <T_STRING@...> "Alice"
[   1] K: <T_SYMBOL> :age
       V: <T_FIXNUM> 30
[   2] K: <T_SYMBOL> :active
       V: <T_TRUE>
~~~

### Large Hashes (ST Table)

For larger hashes, Ruby uses a hash table (output format is similar):

~~~
(gdb) rb-inspect $large_hash
<T_HASH@...>
[   0] K: <T_SYMBOL> :user_id
       V: <T_FIXNUM> 12345
[   1] K: <T_SYMBOL> :session_data
       V: <T_STRING@...> "..."
  ...
~~~

### Controlling Depth

Prevent overwhelming output from deeply nested structures:

~~~
(gdb) rb-inspect $nested_hash --depth 1   # Only top level
<T_HASH@...>
[   0] K: <T_SYMBOL> :data
       V: <T_HASH@...>  # Nested hash not expanded

(gdb) rb-inspect $nested_hash --depth 2   # Expand one level
<T_HASH@...>
[   0] K: <T_SYMBOL> :data
       V: <T_HASH@...>
       [   0] K: <T_SYMBOL> :nested_key
              V: <T_STRING@...> "value"
~~~

At depth 1, nested structures show their type and address but aren't expanded. Increase depth to expand them.

## Inspecting Arrays

Arrays also have two representations based on size:

### Arrays

Arrays display their elements with type information:

~~~
(gdb) rb-inspect $array
<T_ARRAY@...>
[   0] <T_FIXNUM> 1
[   1] <T_FIXNUM> 2
[   2] <T_FIXNUM> 3
~~~

For arrays with nested objects:

~~~
(gdb) rb-inspect $array --depth 2
<T_ARRAY@...>
[   0] <T_STRING@...> "first item"
[   1] <T_HASH@...>
[   0] K: <T_SYMBOL> :key
       V: <T_FIXNUM> 123
  ...
~~~

## Inspecting Structs

Ruby Struct objects work similarly to arrays:

~~~
(gdb) rb-inspect $struct_instance
<T_STRUCT@...>
[   0] <T_STRING@...> "John"
[   1] <T_FIXNUM> 25
[   2] <T_STRING@...> "Engineer"
[   3] <T_TRUE>
~~~

## Practical Examples

### Debugging Exception in Fiber

When a fiber has an exception, inspect it:

~~~
(gdb) rb-fiber-scan-heap
(gdb) rb-fiber-scan-switch 5  # Switch to fiber #5
(gdb) rb-inspect $errinfo --depth 3
~~~

This reveals the full exception structure including any nested causes. After switching to a fiber, `$errinfo` and `$ec` convenience variables are automatically set.

### Inspecting Method Arguments

Break at a method and examine arguments on the stack:

~~~
(gdb) break some_method
(gdb) run
(gdb) rb-inspect $ec->cfp->sp[-1]  # Last argument
(gdb) rb-inspect $ec->cfp->sp[-2]  # Second-to-last argument
~~~

### Examining Fiber Storage

Thread-local variables are stored in fiber storage:

~~~
(gdb) rb-fiber-scan-heap
(gdb) rb-fiber-scan-switch 0
(gdb) rb-inspect $ec->storage --depth 2
~~~

This shows all thread-local variables and their values.

## Debugging with --debug Flag

When `rb-inspect` doesn't show what you expect, use `--debug`:

~~~
(gdb) rb-inspect $suspicious_value --debug
DEBUG: Evaluated '$suspicious_value' to 0x7f8a1c567890
DEBUG: Loaded constant RUBY_T_MASK = 31
DEBUG: Object at 0x7f8a1c567890 with flags=0x20040005, type=0x5
...
~~~

This shows:
- How the expression was evaluated
- What constants were loaded
- Object type detection logic
- Any errors encountered

Use this to troubleshoot:
- Unexpected output format
- Missing nested structures
- Type detection issues
- Access errors
