extends Node

#Put your custom functions here, where the key is the name of the function, and the value is the description.
var custom_functions : Dictionary = {
	"example_change_gravity" : "Example command that changes the gravity to arg[0]"
}

#Commands are defined as follows: Function name is command name, and it takes 2 arguments
#ls - the parsed line, split by white space. This is a PackedStringArray.
#ls[0] will be the function name.
#l - the line of code reconstructed after parsing. This is a string.

#Here is an example of a simple command that changes gravity.
#The name of this function MUST match with key in custom_functions from DevConsoleParent.
func example_change_gravity(ls : PackedStringArray, _l : String):
	if !enforce_minimum_size(ls, 2): return #First, that we have at least 1 argument (The first entry in ls is example_change_gravity)
	var gravity_amount = convert_string_to_var(ls[1]) #Obtain the first argument
	if !check_type_error(gravity_amount, [TYPE_INT, TYPE_FLOAT]): return #Check that the first argument is a number
	
	#Change the setting
	ProjectSettings.set_setting("physics/2d/default_gravity", gravity_amount)

#Converts from string to bool. Assumes that the string is either true or false.
func str_to_bool(text : String) -> bool:
	var t = text.to_lower()
	return t == "true" || int(t) == 1

#Converts from true/false to enabled disabled string. Useful for outputting.
func bool_to_enabled_disabled(b : bool) -> String:
	if b:
		return "enabled"
	else:
		return "disabled"

#Gets the console
func get_console():
	return get_tree().get_first_node_in_group("DevConsole")

#Call to convert string to var
func convert_string_to_var(t : String):
	var r = str_to_var(t)
	if r == null:
		return t
	return r

#Call to check whether or not input belongs to valid types.
func check_type_error(input, valid_types : Array) -> bool:
	var r : bool = valid_types.has(typeof(input))
	if !r:
		log_error("Argument " + str(input) + " is not of type " + str(valid_types))
	return r

func enforce_minimum_size(ls : PackedStringArray, min_size : int) -> bool:
	var r : bool = ls.size()>=min_size
	if !r:
		log_error("Insufficient arguments to call this command" + str(ls.size()) + " < " + str(min_size))
	return r

#Prints an error to the log
func log_error(text : String):
	get_console().print_to_log("[color=red]"+text+"[/color]")

func print_to_console(text : String):
	get_console().print_to_log(text)
