#!/usr/bin/python

import sys


def dump_data(out_stream, data):
	while data:
		line = "\t" + ",".join(map(lambda x: 'x"{:02X}"'.format(x), data[:16]))
		data = data[16:]
		out_stream.write(line + (",\n" if data else "\n"))



def doit(arg, in_stream, out_stream):
	files = {}
	ID_STR = "---INCLUDE-BIN:"
	for a in arg:
		with open(a, "rb") as f:
			files[a] = bytearray(f.read())
	in_context = ""
	lineno = 0
	for line in in_stream:
		lineno += 1
		if ID_STR in line:
			a = line.split(ID_STR, 1)[1].split(":")
			if in_context:
				if len(a) < 2:
					return "Syntax error (too few include elements) in line " + str(lineno)
				if a[0] != "STOP":
					return "Waiting for STOP in context of " + in_context + " but got \"" + ":".join(a) + "\" in line " + str(lineno)
				if a[1] != in_context:
					return "Waiting for STOP of " + in_context + " but got \"" + ":".join(a) + "\" in line " + str(lineno)
				if files:
					dump_data(out_stream, files[in_context])
				else:
					print("-- DATA IS STRIPPED OUT")
				print(line.rstrip())
				in_context = ""
			else:
				if len(a) < 3:
					return "Syntax error (too few include elements) in line " + str(lineno)
				if a[0] != "START":
					return "Waiting for START but got " + a[1] + " in line " + str(lineno)
				if files and a[1] not in files:
					return "Unknown file to include \"" + a[1] + "\" in line " + str(lineno)
				in_context = a[1]
				if files:
					try:
						size = int(a[2])
					except:
						return "Wrong size element \"" + a[2] + "\" in line " + str(lineno)
					if size != len(files[in_context]):
						return "Size mismatch, requested size is " + str(size) + " file size is " + len(files[in_context]) + " in line " + str(lineno)
				print(line.rstrip())
		elif not in_context:
			print(line.rstrip())
	if in_context:
		return "Include context for \"" + in_context + "\" has not been closed, but end of file"
	return True


if __name__ == "__main__":
	ret = doit(sys.argv[1:], sys.stdin, sys.stdout)
	if ret is True:
		sys.exit(0)
	else:
		sys.stderr.write("ERROR: " + str(ret) + "\n")
		sys.exit(1)


