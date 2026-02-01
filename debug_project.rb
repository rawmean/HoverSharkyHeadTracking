require 'xcodeproj'

project_path = 'HoverShark.xcodeproj'
project = Xcodeproj::Project.open(project_path)
group_name = 'HoverBird'
group = project.main_group.find_subpath(group_name)

if group
  puts "Group: #{group.name}"
  puts "Group Path: #{group.path}"
  puts "Group Real Path: #{group.real_path}"
  
  file_ref = group.files.find { |f| f.path.include?('LeaderboardView.swift') }
  if file_ref
    puts "File Ref Path: #{file_ref.path}"
    puts "File Ref Source Tree: #{file_ref.source_tree}"
    puts "File Ref Real Path: #{file_ref.real_path}"
    puts "File Ref Full Path: #{file_ref.full_path}"
  else
    puts "File ref not found in group."
  end
else
  puts "Group not found."
end
