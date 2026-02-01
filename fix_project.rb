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
  puts "Group #{group_name} not found"
  exit 1
end

files_to_fix = [
  'LeaderboardView.swift',
  'LeaderboardViewModel.swift'
]

# Configure the group to use the directory `HoverBird` relative to project (if not already)
# Usually we don't mess with group path unless we know. 
# But let's assuming group path is correct (HoverBird).

files_to_fix.each do |filename|
  # 1. Remove existing references from group and target
  existing_ref = group.files.find { |f| f.path.include?(filename) }
  if existing_ref
    target.source_build_phase.remove_file_reference(existing_ref)
    existing_ref.remove_from_project
    puts "Removed existing reference for #{filename}"
  end
  
  # 2. Add new reference correctly
  # If group is mapped to 'HoverBird', we just need the filename.
  # file_ref = group.new_reference(filename) 
  # Note: new_file is alias for new_reference
  
  file_ref = group.new_reference(filename)
  target.add_file_references([file_ref])
  puts "Re-added #{filename} to target"
end

project.save
puts "Project saved."
