extends VBoxContainer

@onready var editor : CodeEdit = %CodeEdit
@onready var clog : RichTextLabel = %Log

var default_functions : Dictionary = {
	"help" : "Displays all the default commands and their descriptions.",
	"help2" : "Displays all other commands and their descriptions.",
	"execute" : "Executes all the commands, while clearing the editor",
	"execute_keep" : "Executes all the commands, and keeps the editor",
	"echo" : "Prints the text following echo",
	"clear" : "Clears the console log",
	"times" : "Causes everything until \"end\" to loop args number of times. You can also call for instead.",
	"loop_forever" : "loops until break is called. Will crash your game if you don't break",
	"end" : "Used to terminate loops",
	"var" : "Can be used to create variables. You can also create arrays this way",
	"append": "Used to append values to arrays.",
	"append_array" : "Used to append arrays to arrays",
	"remove_at" : "Used to remove values from arrays",
	"if" : "Runs following code if args is true.",
	"endif" : "Ends an if statement",
	"break" : "Breaks out of current loop",
	"concat" : "Add strings to a string. Use like concat var1 hello world"
}
#Use # to comment
#"eval"
#"=" : "Assignment to variable","+=, -=, *=, /=, %=" : "Mathematical assignment"
var function_names : PackedStringArray = []

var custom_functions : Dictionary = {}
var function_dictionary : Dictionary
var ended_commands : PackedStringArray = PackedStringArray(["for","times","loop_forever"])
@onready var syntax_highlighter = %CodeEdit.syntax_highlighter
var previous_num_lines : int = 1
#Used as a delimiter for splitting purposes.
var delimiter : String = "¬"
var variables : Array = []
#Stores dictionaries depending on the scope.

# Called when the node enters the scene tree for the first time.
func _ready():
	#Retrieve the list of custom functions.
	custom_functions = DevConsoleHandler.custom_functions
	#Combine the function dictionaries.
	function_dictionary = default_functions.duplicate()
	function_dictionary.merge(custom_functions, false)
	#Makes an array of all the function names.
	function_names = function_dictionary.keys()
	editor.code_completion_prefixes = function_names
	for word in default_functions:
		if word != "var":
			editor.syntax_highlighter.add_keyword_color(word, Color.ORCHID)
		else:
			editor.syntax_highlighter.add_keyword_color(word, Color.DARK_ORANGE)
	for word in custom_functions:
		if word != "cheat":
			editor.syntax_highlighter.add_keyword_color(word, Color.DEEP_SKY_BLUE)
		else:
			editor.syntax_highlighter.add_keyword_color(word, Color.RED)
	for word in ["true", "false"]:
		editor.syntax_highlighter.add_keyword_color(word, Color.INDIAN_RED)
	for word in ["array", "arr"]:
		editor.syntax_highlighter.add_keyword_color(word, Color.SPRING_GREEN)
	editor.syntax_highlighter.add_keyword_color("eval", Color.LAWN_GREEN)

func _on_code_edit_code_completion_requested():
	for each in function_names:
		editor.add_code_completion_option(CodeEdit.KIND_FUNCTION, each, each+" ", Color.YELLOW_GREEN)
	editor.update_code_completion_options(true)


func _on_code_edit_text_changed():
	editor.request_code_completion(true)
	var line_changes : int = 0
	if previous_num_lines != editor.get_line_count():
		line_changes = editor.get_line_count() - previous_num_lines
		previous_num_lines = editor.get_line_count()
	if line_changes > 0 && editor.get_caret_line()>=editor.get_line_count()-1 && editor.text.ends_with("\n"):
		_on_code_edit_new_final_line()


#Called when the user types a new line at the very end.
func _on_code_edit_new_final_line():
	#Check if the user has 3 new lines in a row.
	
	var lastLine : String = editor.get_line(editor.get_line_count()-2)
	var lastLineSplit : PackedStringArray = split_white_space(lastLine)
	if !lastLineSplit.is_empty():
		match lastLineSplit[0].to_lower():
			"execute":
				variables = []
				enter_scope()
				execute()
				clear_editor()
				return
			"execute_keep":
				variables = []
				enter_scope()
				execute()
				return
	if editor.get_line_count() >= 3 && remove_white_spaces(editor.get_line(editor.get_line_count()-3)) == "":
		variables = []
		enter_scope()
		execute()
		clear_editor()
		return

func execute(pointer_start : int = 0, pointer_end : int = -1) -> bool:
	if pointer_start == 0 && clog.text != "":
		print_to_log("\n")
	if pointer_end == -1:
		pointer_end = editor.get_line_count()
	#var last_loop_start : int = pointer_start
	var pointer : int = pointer_start
	var oldest_scope = variables.size()
	while pointer < pointer_end:
		var l : String = editor.get_line(pointer)
		#Line at pointer
		var ls : PackedStringArray = split_white_space(l)
		var lsp = replace_vars_with_values(ls)
		ls = lsp[0]
		#for i in lsp[1]:
			#l = l.replace(i, str(lsp[1][i]))
		ls = replace_arrs_with_values(ls)
		l = " ".join(ls)
		ls = apply_evaluation(ls, l)
		l = " ".join(ls)
		#Array of the line split by white spaces at pointer
		if !ls.is_empty():
			var command_name : String = ls[0].to_lower()
			match command_name:
				"#", "//":
					pass
				"execute", "execute_keep":
					pass #These commands are ignored.
				"for", "times":
					#var val : int = int(ls[1])-1
					oldest_scope = variables.size()
					var val = str_to_var(ls[1])
					if typeof(val) != TYPE_INT:
						log_error("Argument for " + ls[0] + ": " + ls[1] + " is not an integer")
					else:
						val -= 1
						var broken : bool = false
						var ending_ind : int = -1
						if val > 0:
							ending_ind = find_end_index(pointer, pointer_end)
							for i in val:
								enter_scope()
								broken = execute(pointer + 1, ending_ind)
								if broken:
									break
						if !broken:
							enter_scope()
						else:
							variables.resize(oldest_scope)
							pointer = ending_ind
				"loop_forever":
					oldest_scope = variables.size()
					var broken : bool = false
					var ending_ind : int = find_end_index(pointer, pointer_end)
					while true:
						enter_scope()
						broken = execute(pointer + 1, ending_ind)
						if broken:
							break
					variables.resize(oldest_scope)
					pointer = ending_ind
				"if":
					var val = ls[1].to_lower()
					if val != "true" && val != "false" && val != "1" && val != "0":
						log_error("Argument for " + ls[0] + ": " + ls[1] + " is not a boolean")
					else:
						if val == "true" || val == "1":
							enter_scope()
						else:
							#Fast forward to the next end
							var p2 : int = pointer + 1
							var comm : int = 0 #comm counts number of ended commands that are encountered - number of ends encountered.
							while p2 < pointer_end && comm >= 0:
								var l2 : String = editor.get_line(p2)
								#Line at pointer
								var ls2 : PackedStringArray = split_white_space(l2)
								if ls2.size() > 0:
									var ls3 = ls2[0].to_lower()
									if ["if"].has(ls3):
										comm += 1
									elif ls3 == "endif":
										comm -= 1
								p2 += 1
							pointer = p2-1
				"break":
					pointer = pointer_end #find_end_index(last_loop_start, pointer_end)
					return true
				"end":
					exit_scope()
					if pointer_start != 0:
						return false
				"endif":
					exit_scope()
				"echo":
					echo(l)
				"clear":
					clear_clog()
				"help":
					help()
				"help2":
					help2()
				"help3":
					help3()
				#"hi_hit":
					#print_to_log("[rainbow][tornado]HI HIT EVERYDAY, FOREVER FUTURE[/tornado][/rainbow]")
				#"lo_hit":
					#get_tree().quit()
				"var":
					create_var(ls, l)
				"append":
					append(ls)
				"append_array":
					append_array(ls)
				"concat":
					concatenate(ls)
				"remove_at":
					remove_at(ls)
				_:
					var found : bool = false
					if custom_functions.has(command_name):
						DevConsoleHandler.call(command_name, ls, l)
					elif ls.size() >= 3:
						var i = ls[0]
						if i.to_lower() == "array" || i.to_lower() == "arr":
							if ls.size() < 5:
								log_error("Incorrect use of array command")
							else:
								i = ls[1]
								for a in variables:
									if a.has(i):
										if typeof(a[i]) != TYPE_ARRAY:
											log_error(i + " is not an array")
											break
										else:
											found = true
											var ind = str_to_var(ls[2])
											if typeof(ind) != TYPE_INT:
												log_error("index " + str(ind) + "not integer")
											else:
												if ind >= a[i].size() || ind < 0:
													log_error("index " + str(ind) + " invalid for array " + i + " of size " + str(a[i].size()))
													break
												var assignment: String =  ls[3]
												var targetls = ls.duplicate()
												targetls.remove_at(0)
												targetls.remove_at(0)
												targetls.remove_at(0)
												targetls.remove_at(0)
												var target = " ".join(targetls)
												var target_var = str_to_var(target)
												match assignment:
													"+=":
														if check_if_number(target_var) && check_if_number(a[i][ind]):
															a[i][ind] += target_var
														else:
															log_error(target + " is invalid assignment target")
													"-=":
														if check_if_number(target_var) && check_if_number(a[i][ind]):
															a[i][ind] -= target_var
														else:
															log_error(target + " is invalid assignment target")
													"*=":
														if check_if_number(target_var) && check_if_number(a[i][ind]):
															a[i][ind] *= target_var
														else:
															log_error(target + " is invalid assignment target")
													"/=":
														if check_if_number(target_var) && check_if_number(a[i][ind]):
															if target_var == 0:
																log_error("Naughty naughty, no division by 0 allowed. Command ignored.")
															else:
																a[i][ind] /= target_var
														else:
															log_error(target + " is invalid assignment target")
													"%=":
														if check_if_number(target_var) && check_if_number(a[i][ind]):
															if target_var == 0:
																log_error("Naughty naughty, no modulo by 0 allowed. Command ignored.")
															else:
																a[i][ind] %= target_var
														else:
															log_error(target + " is invalid assignment target")
													"=":
														if target_var != null:
															a[i][ind] = target_var
														else:
															a[i][ind] = target
												break
						else:
							for a in variables:
								if a.has(i):
									found = true
									var assignment: String =  ls[1]
									var targetls = ls.duplicate()
									targetls.remove_at(0)
									targetls.remove_at(0)
									var target = " ".join(targetls)
									var target_var = str_to_var(target)
									match assignment:
										"+=":
											if check_if_number(target_var) && check_if_number(a[i]):
												a[i] += target_var
											else:
												log_error(target + " is invalid assignment target")
										"-=":
											if check_if_number(target_var) && check_if_number(a[i]):
												a[i] -= target_var
											else:
												log_error(target + " is invalid assignment target")
										"*=":
											if check_if_number(target_var) && check_if_number(a[i]):
												a[i] *= target_var
											else:
												log_error(target + " is invalid assignment target")
										"/=":
											if check_if_number(target_var) && check_if_number(a[i]):
												if target_var == 0:
													log_error("Naughty naughty, no division by 0 allowed. Command ignored.")
												else:
													a[i] /= target_var
											else:
												log_error(target + " is invalid assignment target")
										"%=":
											if check_if_number(target_var) && check_if_number(a[i]):
												if target_var == 0:
													log_error("Naughty naughty, no modulo by 0 allowed. Command ignored.")
												else:
													a[i] %= target_var
											else:
												log_error(target + " is invalid assignment target")
										"=":
											if target_var != null:
												a[i] = target_var
											else:
												a[i] = target
										_:
											log_error("Assignment" + assignment + " not recognized")
									break
						if !found:
							log_error("Command " + l + " not recognized")
					else:
						log_error("Command " + l + " not recognized")
		pointer += 1
	exit_scope()
	return false

func remove_at(ls : PackedStringArray):
	if ls.size() < 3:
		log_error("Insufficient number of parameters for append")
		return
	var identifier_name = ls[1]
	for a in variables:
		if a.has(identifier_name):
			if typeof(a[identifier_name]) != TYPE_ARRAY:
				log_error(identifier_name + " is not type array")
				break
				return
			else:
				var ind = str_to_var(ls[2])
				if typeof(ind) == TYPE_INT:
					if ind >= a[identifier_name].size() || ind < 0:
						log_error("index " + str(ind) + " invalid for array " + identifier_name + " of size " + str(a[identifier_name].size()))
						break
						return
					else:
						a[identifier_name].remove_at(ind)
						return
				else:
					log_error(ls[2] + " is not a valid index")
					return

func append(ls : PackedStringArray):
	if ls.size() < 3:
		log_error("Insufficient number of parameters for append")
		return
	var identifier_name = ls[1]
	for a in variables:
		if a.has(identifier_name):
			if typeof(a[identifier_name]) != TYPE_ARRAY:
				log_error(identifier_name + " is not type array")
				return
			else:
				var target = str_to_var(ls[2])
				if target == null:
					a[identifier_name].push_back(ls[2])
				else:
					a[identifier_name].push_back(target)
				return
	log_error("Identifier " + identifier_name + " not found")

func append_array(ls : PackedStringArray):
	if ls.size() < 3:
		log_error("Insufficient number of parameters for append_array")
		return
	var identifier_name = ls[1]
	for a in variables:
		if a.has(identifier_name):
			if typeof(a[identifier_name]) != TYPE_ARRAY:
				log_error(identifier_name + " is not type array")
				return
			else:
				var target = str_to_var(ls[2])
				if typeof(target) == TYPE_ARRAY:
					a[identifier_name].append_array(target)
				else:
					log_error(str(ls[2]) + " is not type array")
				return
	log_error("Identifier " + identifier_name + " not found")

func create_var(ls : PackedStringArray, l : String):
	var already_defined : bool = false
	var var_pointer : int = 0
	if !check_if_valid_variable_name(ls[1]):
		log_error("Variable name " + ls[1] + " is invalid because it shares the same name as a function or it isn't a string.")
	else:
		var arg = remove_by_keyword(remove_by_keyword(l, ls[1]), "=")
		var aarg = str_to_var(arg)
		if aarg != null:
			arg = aarg
		for d in variables:
			if d.has(ls[1]):
				already_defined = true
				break
			var_pointer += 1
		if already_defined:
			log_error("Variable " + ls[1] + " is already defined. Overwriting the variable")
			variables[var_pointer][ls[1]] = arg
		else:
			variables.back()[ls[1]] = arg
#Echo first removes the Echo prefix from the text.
func echo(text : String) : 
	var ind1 : int = text.findn("echo") + 5
	print_to_log(text.substr(ind1))

func log_error(text : String):
	print_to_log("[color=red]"+text+"[/color]")
	print("Console: Error occured")

func print_to_log(text : String):
	clog.text = clog.text + "\n" + text

func clear_editor():
	editor.text = ""
	previous_num_lines = 1

func clear_clog():
	clog.text = ""

#Returns the string without white spaces
func remove_white_spaces(t : String) -> String:
	var regex = RegEx.new()
	regex.compile("\\s+")
	return regex.sub(t,"", true)

#Splits the string into an array by the white spaces
func split_white_space(t : String) -> PackedStringArray:
	var regex = RegEx.new()
	#regex.compile("\\s+")
	regex.compile("\\s+(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)")
	var res : String = regex.sub(t,delimiter,true)
	return res.split(delimiter, false)

func help():
	display_dictionary(default_functions)

func help2():
	display_dictionary(custom_functions)

func help3():
	display_dictionary(function_dictionary)

func display_dictionary(dict : Dictionary):
	for key in dict:
		clog.text = clog.text + "\n" + str(key) + " : " + dict[key]

#Called when you enter a new scope.
func enter_scope():
	variables.push_back({})

#Called when you exit a scope.
func exit_scope():
	variables.pop_back()

#Combines a string, starting from the "from" element till the end.
#For instance, arr_str(['a','b','c','d'], 2) returns 'cd'
func combine_till_end(arr_str : PackedStringArray, from : int) -> String:
	var combined : String = ""
	var counter : int = 0
	for g in arr_str:
		counter += 1
		if counter > from:
			combined = combined + g
	return combined

#Removes every word before num whitespaces.
#For instance, reduce_string_by_whitespaces("hello world again", 1) returns "world again"
#func reduce_string_by_whitespaces(str : String, num : int) -> String:
#	var left : String = str
#	for i in num:
#		var sto : int = left.find(" ", 0)
#		if sto == -1:
#			return left
#		#left.substr()
#	return left

func check_if_valid_variable_name(n : String) -> bool:
	var typ : int = typeof(str_to_var(n))
	#typ = typeof(str_to_var("HelloIamString"))
	return !function_names.has(n) && (typ == TYPE_STRING || typ == TYPE_NIL)

func check_if_number(n) -> bool:
	var typ : int = typeof(n)
	return typ == TYPE_INT || typ == TYPE_FLOAT

#Removes everything after the first instance of key in str.
func remove_by_keyword(stri : String, key : String) -> String:
	var s : int = stri.find(key)
	if s == -1:
		return stri
	s += key.length()
	return stri.substr(s)

func replace_vars_with_values(ls : PackedStringArray) -> Array:
	var lsc : PackedStringArray = ls.duplicate()
	if lsc.size() == 0:
		return [lsc, {}]
	var first = lsc[0]
	var skip : bool = false
	var first_word_skip = ["array", "arr", "append", "append_array", "remove_at", "var", "concat"]
	if first_word_skip.has(first.to_lower()):
		skip = true
	lsc.remove_at(0)
	var o = {}
	for b in lsc.size():
		if skip:
			skip = false
			continue
		var i = lsc[b]
		if i.to_lower() == "array" || i.to_lower() == "arr":
			skip = true
			continue
		for a in variables:
			if a.has(i):
				o[i] = a[i]
				lsc[b] = str(a[i])
				break
	lsc.insert(0, first)
	return [lsc, o]

func replace_arrs_with_values(ls : PackedStringArray) -> PackedStringArray:
	var start_pointer : int = 1
	if ls.size() == 0:
		return ls
	if ls[0].to_lower() == "array" || ls[0].to_lower() == "arr":
		start_pointer = 3
	var pointer : int = 0
	var o := PackedStringArray()
	var identifier : bool = false
	var identifier_name : String = ""
	var index : bool = false
	while pointer < ls.size():
		if pointer < start_pointer:
			o.append(ls[pointer])
		else:
			if ls[pointer].to_lower() == "array" || ls[pointer].to_lower() == "arr":
				identifier = true
			elif identifier:
				identifier_name = ls[pointer]
				identifier = false
				index = true
			elif index:
				var ind = str_to_var(ls[pointer])
				if typeof(ind) != TYPE_INT:
					log_error("Index of array is not integer")
				else:
					for a in variables:
						if a.has(identifier_name):
							if typeof(a[identifier_name]) != TYPE_ARRAY:
								log_error(identifier_name + " is not type array")
								break
							elif ind >= a[identifier_name].size() || ind < 0:
								log_error("index " + str(ind) + " invalid for array " + identifier_name + " of size " + str(a[identifier_name].size()))
							else:
								o.append(str(a[identifier_name][ind]))
								break
			else:
				o.append(ls[pointer])
		pointer += 1
	#print("o is :" + str(o))
	#print(variables)
	return o

func apply_evaluation(ls : PackedStringArray, l : String) -> PackedStringArray:
	var loc_eval : int = ls.find("eval")
	if loc_eval == -1:
		return ls
	var reconstruct : PackedStringArray = ls.slice(0,loc_eval)
	var expression = Expression.new()
	var ind1 : int = l.findn("eval") + 5
	var err = expression.parse(l.substr(ind1))
	if err != OK:
		log_error(expression.get_error_text())
	var result = expression.execute()
	if not expression.has_execute_failed():
		reconstruct.push_back(var_to_str(result))
	return reconstruct

func find_end_index(pointer : int, pointer_end : int) -> int:
	var p2 : int = pointer + 1
	var comm : int = 0 #comm counts number of ended commands that are encountered - number of ends encountered.
	while p2 < pointer_end && comm >= 0:
		var l2 : String = editor.get_line(p2)
		#Line at pointer
		var ls2 : PackedStringArray = split_white_space(l2)
		if ls2.size() > 0:
			var ls3 = ls2[0].to_lower()
			if ended_commands.has(ls3):
				comm += 1
			elif ls3 == "end":
				comm -= 1
		p2 += 1
	return p2-1

func concatenate(ls : PackedStringArray):
	if ls.size() < 3:
		log_error("Insufficient number of parameters for concat")
		return
	var identifier_name = ls[1]
	for a in variables:
		if a.has(identifier_name):
			if typeof(a[identifier_name]) != TYPE_STRING:
				log_error(identifier_name + " is not type string")
				break
			else:
				var point : int = 2
				while point < ls.size():
					a[identifier_name] = a[identifier_name] + ls[point]
					point += 1
				return
	log_error("identifier " + identifier_name + " not found")
