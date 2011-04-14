#!/usr/bin/env ruby -wKU

#Jacob Hamack
#jacob.hammack@hammackj.com
#http://www.hammackj.com

def rename_files_by_type (type, old_vm_name, new_vm_name)
	file_of_type = Dir["*.#{type}"]

	file_of_type.each do |old_file_name|
		new_file_name = old_file_name.sub(old_vm_name, new_vm_name)
		
		if old_file_name == new_file_name
			next
		else
			File.rename(old_file_name, new_file_name)
		end
	end
end

def file_type(file)
	type = `file '#{file}'`.split(":")[1]
end

def process_vmdk_files(old_vm_name, new_vm_name)
	vmdk_files = Dir["*.vmdk"]
	
	vmdk_files.each do |file|
		type = file_type file
		new_file_name = file.sub(old_vm_name, new_vm_name)
		
		if type =~ /ASCII English text/							
			File.open("#{new_file_name}", "w+") do |output|
				File.open("#{file}", "r") do |input|
					while (line = input.gets)
						if line =~ /\"#{old_vm_name}-s\d\d\d.vmdk\"/
			 				line = line.sub(old_vm_name, new_vm_name)
						elsif line =~ /\"#{old_vm_name}-\d*-s\d\d\d.vmdk\"/
							line = line.sub(old_vm_name, new_vm_name)
						elsif line =~ /parentFileNameHint/
							line = line.sub(old_vm_name, new_vm_name)
						else
							line = line
						end

						output.write line
					end
				end
			end
			
			system("rm '#{file}'")
			
		elsif type =~ /VMware4 disk image/
			File.rename(file, new_file_name)
		else
			puts "[!] Broken vmdk: #{file}"
		end
	end
end

def process_vmx_file(old_vm_name, new_vm_name)
	File.open("#{new_vm_name}.vmx", "w+") do |output|
		File.open("#{old_vm_name}.vmx", "r") do |input|
			while (line = input.gets)		
				if line =~ /scsi0:0.fileName/
					line = line.gsub("#{old_vm_name}", "#{new_vm_name}")
				elsif line =~ /displayName/
					line = line.gsub("#{old_vm_name}", "#{new_vm_name}")
				elsif line =~ /extendedConfigFile/
					line = line.gsub("#{old_vm_name}.vmxf", "#{new_vm_name}.vmxf")
				elsif line =~ /nvram/
					line = ""
				elsif line =~ /sched.swap.derivedName/
					line = line.gsub("#{old_vm_name}", "#{new_vm_name}")
				elsif line =~ /checkpoint.vmState/
					line = line.gsub("#{old_vm_name}", "#{new_vm_name}")
				else
					line = line
				end
		
				output.write line
			end
		end
	end
	system("rm '#{old_vm_name}.vmx'")
end

def process_vmxf_file(old_vm_name, new_vm_name)
	File.open("#{new_vm_name}.vmxf", "w+") do |output|
		File.open("#{old_vm_name}.vmxf", "r") do |input|
			while (line = input.gets)
				if line =~ /vmxPathName/
					line = line.gsub("#{old_vm_name}.vmx", "#{new_vm_name}.vmx")
				else
					line = line
				end
		
				output.write line
			end
		end
	end

	system("rm '#{old_vm_name}.vmxf'")
end

def process_vmsd_file(old_vm_name, new_vm_name)
	File.open("#{new_vm_name}.vmsd", "w+") do |output|
		File.open("#{old_vm_name}.vmsd", "r") do |input|
			while (line = input.gets)		
				if line =~ /fileName/ or line =~ /filename/
					line = line.sub("#{old_vm_name}", "#{new_vm_name}")
				else
					line = line
				end
		
				output.write line
			end
		end
	end
	system("rm '#{old_vm_name}.vmsd'")
end


file = ARGV[0]
newfile = ARGV[1]

if file[-1] == "/"
	file = file[0...file.rindex('/')]
end

if newfile[-1] == "/"
	newfile = newfile[0...newfile.rindex('/')]
end

#1. Copy existing vm to new path
puts "[*] Cloning #{file} to #{newfile}"
system("cp -r '#{file}'/ '#{newfile}'/")

#clean up the new vm
puts "[*] Clean #{newfile}"
Dir.chdir("#{newfile}/")

file = file.gsub(".vmwarevm", "")
newfile = newfile.gsub(".vmwarevm", "")

#Remove all of the pointless stuff
system("rm *.nvram")
system("rm -rf *.lck")
system("rm -rf Applications/")
system("rm -rf appListCache")
system("rm *.log")
system("rm quicklook-cache.png")

puts "[*] Fixing disk references"
process_vmdk_files(file, newfile)

puts "[*] Fixing #{newfile}.vmx"
process_vmx_file(file, newfile)

puts "[*] Fixing #{newfile}.vmxf"
process_vmxf_file(file, newfile)

puts "[*] Fixing Snapshots"
puts "[*] Fixing *.vmem"
rename_files_by_type("vmem", file, newfile)

puts "[*] Fixing *.vmsn"
rename_files_by_type("vmsn", file, newfile)

puts "[*] Fixing *.vmss"
rename_files_by_type("vmss", file, newfile)

puts "[*] Fixing vmsd"
process_vmsd_file(file, newfile)
