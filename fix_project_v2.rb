require 'xcodeproj'

project_path = 'HoverShark.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'HoverSharky'
target = project.targets.find { |t| t.name == target_name }

group_name = 'HoverBird'
group = project.main_group.find_subpath(group_name)

files_to_fix = [
  'LeaderboardView.swift',
  'LeaderboardViewModel.swift'
]

files_to_fix.each do |filename|
  # 1. Remove existing references from group and target
  # Search recursively or in group
  existing_ref = group.files.find { |f| f.path.include?(filename) }
  if existing_ref
    target.source_build_phase.remove_file_reference(existing_ref)
    existing_ref.remove_from_project
    puts "Removed existing reference for #{filename}"
  end
  
  # 2. Add new reference relative to SOURCE_ROOT
  # This avoids group path inheritance issues
  full_path = "HoverBird/#{filename}"
  file_ref = group.new_reference(full_path)
  file_ref.source_tree = 'SOURCE_ROOT'
  
  target.add_file_references([file_ref])
  puts "Re-added #{filename} to target with SOURCE_ROOT relative path"
end

project.save
puts "Project saved."
