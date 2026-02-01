require 'xcodeproj'

project_path = 'HoverShark.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'HoverSharky'
target = project.targets.find { |t| t.name == target_name }

if target.nil?
  puts "Error: Target #{target_name} not found"
  exit 1
end

group_name = 'HoverBird'
group = project.main_group.find_subpath(group_name)

if group.nil?
  puts "Group #{group_name} not found, using main group"
  group = project.main_group
end

files_to_add = [
  'HoverBird/LeaderboardView.swift',
  'HoverBird/LeaderboardViewModel.swift'
]

files_to_add.each do |file_path|
  # Create a reference for the file
  # Note: new_file automatically handles adding it to the group and setting the path
  file_ref = group.new_file(File.basename(file_path)) 
  
  # Set the path correctly if it's not strictly relative to the group (handling complex cases)
  # But usually new_file attempts to be smart. 
  # Let's ensure the path is set relative to project if needed, or rely on xcodeproj
  # Attempting to re-set path just in case
  file_ref.path = file_path 
  
  if !target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added #{file_path} to target #{target_name}"
  else
    puts "#{file_path} already in target"
  end
end

project.save
puts "Project saved."
