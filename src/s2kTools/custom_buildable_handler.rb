module CustomBuildableHandler
  def self.activate
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("No component selected.")
      return
    end

    selection.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance)
        if entity.definition.attribute_dictionary('dynamic_attributes') &&
           entity.definition.get_attribute('dynamic_attributes', 'class') == 'buildable'
          self.process_component(entity)
        else
          UI.messagebox("Selected component is not part of the 'buildable' class.")
        end
      else
        UI.messagebox("Please select a component.")
      end
    end
  end

  def self.process_component(component)
    model = Sketchup.active_model
    model.start_operation("Process Buildable Component", true)

    # Store the initial entities for comparison
    initial_entities = model.active_entities.to_a

    # Explode the main component
    exploded_entities = component.explode

    # Explode child components
    exploded_entities.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance)
        exploded_entities.concat(entity.explode)
      end
    end

    # Perform custom cleanup on the exploded entities
    self.custom_cleanup

    # Identify new entities created by the explode operation
    final_entities = model.active_entities.to_a
    new_entities = final_entities - initial_entities

    # Group and create a new component from the new entities
    unless new_entities.empty?
      new_group = model.active_entities.add_group(new_entities)
      new_component = new_group.to_component
      new_component.definition.name = "Processed Component"
    else
      puts "No valid entities left to group."
    end

    model.commit_operation
  end

  def self.custom_cleanup
    model = Sketchup.active_model
    entities = model.active_entities
  
    model.start_operation("Custom Cleanup", true)
  
    # Remove stray edges
    stray_edges = entities.grep(Sketchup::Edge).select { |e| e.faces.empty? }
    entities.erase_entities(stray_edges)
  
    # Merge coplanar faces
    Sketchup.send_action('fixNonPlanarFaces:')
  
    # Remove edges between coplanar faces
    coplanar_edges = entities.grep(Sketchup::Edge).select do |edge|
      faces = edge.faces
      next false if faces.size != 2 # Edge must be shared by exactly two faces
      normal1 = faces[0].normal
      normal2 = faces[1].normal
      # Check if both faces are coplanar
      normal1.parallel?(normal2) && (faces[0].plane[3] - faces[1].plane[3]).abs < 0.001
    end
    entities.erase_entities(coplanar_edges)
  
    model.commit_operation
    puts "Custom cleanup completed with coplanar edge removal."
  end
  

  # Add a right-click context menu entry
  UI.add_context_menu_handler do |menu|
    menu.add_item("Process Buildable Component") { self.activate }
  end
end
