require 'xcodeproj'

project_path = 'HoverShark.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'HoverSharky'
target = project.targets.find { |t| t.name == target_name }

if target.nil?
  puts "Error: Target #{target_name} not found"
  exit 1
end

# Find and remove the incorrect references first
project.files.each do |file|
  if file.path && (file.path.include?('YellowSubmarine.png') || file.path.include?('RedSubmarine.png'))
    puts "Removing: #{file.path}"
    file.remove_from_project
  end
end

# Find HoverBird group
group_name = 'HoverBird'
group = project.main_group.find_subpath(group_name)

if group.nil?
  puts "Group #{group_name} not found, using main group"
  group = project.main_group
end

# Add the files with correct relative paths (relative to group, not nested)
files_to_add = ['YellowSubmarine.png', 'RedSubmarine.png']

files_to_add.each do |file_name|
  # Create file reference with just the filename (path relative to HoverBird group)
  file_ref = group.new_file(file_name)
  # The path should be just the filename since files are in HoverBird folder
  file_ref.path = file_name
  file_ref.source_tree = '<group>'
  
  # Add to resources build phase
  target.add_resources([file_ref])
  puts "Added #{file_name} to target #{target_name}"
end

project.save
puts "Project saved."
