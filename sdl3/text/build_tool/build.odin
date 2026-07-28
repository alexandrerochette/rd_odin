package build_tool

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

main :: proc() {
	shaders_dir := "shaders"

	// Open and read the shaders directory
	handle, err := os.open(shaders_dir)
	if err != os.ERROR_NONE {
		fmt.eprintfln("Failed to open shaders directory: %v", err)
		os.exit(1)
	}
	defer os.close(handle)

	infos, read_err := os.read_dir(handle, -1, context.allocator)
	if read_err != os.ERROR_NONE {
		fmt.eprintfln("Failed to read shaders directory: %v", read_err)
		os.exit(1)
	}
	defer delete(infos)

	for info in infos {
		// Only process files ending with .slang
		if info.type == .Directory || !strings.has_suffix(info.name, ".slang") {
			continue
		}
		// Build the clean relative paths


		file_name := info.name

		// Define the process description required by dev-2026 core:os

		is_fragment := strings.has_suffix(file_name, "fragment.slang") 
		is_vertex := strings.has_suffix(file_name, "vertex.slang")
		if !is_fragment && !is_vertex {
			is_fragment = true
			is_vertex = true
		}
		if is_fragment {
			run_compiler(file_name, shaders_dir, .fragment)
		}
		if is_vertex {
			run_compiler(file_name, shaders_dir, .vertex)
		}


	}

}

stage:: enum {
	fragment,
	vertex
}

run_compiler:: proc(file_name, input_directory : string, stage: stage ) {
		input_path, err := filepath.join({input_directory, file_name})
		defer delete(input_path)
		
	
		desc: os.Process_Desc
		entrypoint_name: string
		stage_name: string
		switch stage {
			case .fragment: 
			entrypoint_name = "FSMain"
			stage_name = "fragment"
			case .vertex:
			entrypoint_name = "VSMain"
			stage_name = "vertex"
		}

		base_name := strings.trim_suffix(file_name, ".slang")
		base_name = strings.trim_suffix(base_name, stage_name)
		base_name = strings.trim_suffix(base_name, ".")
		
		output_name := fmt.tprintf("%s.%s.metallib", base_name, stage_name)
		output_path, output_path_err := filepath.join({"./.generated/", output_name})

		desc.command = []string {
			"./.dependencies/slang/bin/slangc",
			input_path,
			"-target",
			"metallib",
			"-entry",
			entrypoint_name,
			"-stage",
			stage_name,
			"-o",
			output_path,
		}

		// Execute the process and capture the state
		state, stdout, stderr, exec_err := os.process_exec(desc, context.allocator)
		defer delete(stdout)
		defer delete(stderr)
		if exec_err != os.ERROR_NONE {
			fmt.eprintfln("Failed to run slangc for %s: %v", input_path, exec_err)
			os.exit(1)
		}

		// Check the exit code of the external binary
		if state.exit_code != 0 {
			fmt.eprintfln("slangc failed on %s with code %d", input_path, state.exit_code)
			os.exit(1)
		} else {
			fmt.printf("Successfully compiled: %s -> %s\n", input_path, output_name)
		}
}