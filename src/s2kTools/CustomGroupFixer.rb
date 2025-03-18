module CustomGroupFixer
  def self.fix_selected_group
    model = Sketchup.active_model
    selection = model.selection

    # Ensure only one group is selected
    if selection.size != 1 || !selection[0].is_a?(Sketchup::Group)
      UI.messagebox("Please select a single group to fix.")
      return
    end

    # Get the selected group
    selected_group = selection[0]

    # Save the Tag (layer) of the selected group
    group_tag = selected_group.layer

    # Explode the selected group
    model.start_operation("Fix Group Axes", true)
    exploded_entities = []
    selected_group.explode.each do |entity|
      exploded_entities << entity if entity.valid?
    end

    # Ensure all entities are in the active context
    active_entities = model.active_entities
    valid_entities = exploded_entities.select { |entity| active_entities.include?(entity) }

    # Create a new group from the valid entities
    if valid_entities.empty?
      UI.messagebox("No entities found to regroup.")
      model.abort_operation
      return
    end

    new_group = active_entities.add_group(valid_entities)

    # Assign the saved Tag (layer) to the new group
    new_group.layer = group_tag

    model.commit_operation
    UI.messagebox("Group axes fixed and regrouped.")
  end

  # Add a context menu option
  UI.add_context_menu_handler do |menu|
    menu.add_item("Fix Group Axes") { self.fix_selected_group }
  end
end
