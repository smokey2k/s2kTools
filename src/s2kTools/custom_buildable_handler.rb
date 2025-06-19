module CustomBuildableHandler
  def self.activate
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("No component selected.")
      return
    end

    selection.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        if entity.respond_to?(:definition) &&
           entity.definition.attribute_dictionary('dynamic_attributes') &&
           entity.definition.get_attribute('dynamic_attributes', 'class') == 'buildable'
          self.process_component(entity)
        else
          UI.messagebox("Selected object is not part of the 'buildable' class.")
        end
      else
        UI.messagebox("Please select a component or group.")
      end
    end
  end

  def self.process_component(component)
    model = Sketchup.active_model
    model.start_operation("Process Buildable Component", true)

    puts "Exploding top-level component/group..."
    initial_entities = model.active_entities.to_a

    exploded_entities = component.explode
    puts "Top-level exploded into #{exploded_entities.size} entities."

    self.recursively_explode(exploded_entities, exploded_entities)

    self.custom_cleanup

    final_entities = model.active_entities.to_a
    new_entities = final_entities - initial_entities

    puts "New entities after explode and cleanup: #{new_entities.size}"

    if new_entities.empty?
      UI.messagebox("No geometry left to group — maybe the component was empty or cleanup removed everything.")
    else
      new_group = model.active_entities.add_group(new_entities)
      new_component = new_group.to_component
      new_component.definition.name = "Processed Component"
      puts "New component created successfully."
    end

    model.commit_operation
  end

  def self.recursively_explode(entities, exploded_entities)
    entities.each do |entity|
      next unless entity.valid?
      if entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        puts "Recursively exploding: #{entity.respond_to?(:definition) ? entity.definition.name : 'Group'}"
        children = entity.explode
        exploded_entities.concat(children)
        self.recursively_explode(children, exploded_entities)
      end
    end
  end

  def self.custom_cleanup
    model = Sketchup.active_model
    entities = model.active_entities

    model.start_operation("Custom Cleanup", true)

    stray_edges = entities.grep(Sketchup::Edge).select { |e| e.faces.empty? }
    entities.erase_entities(stray_edges)

    Sketchup.send_action('fixNonPlanarFaces:')

    coplanar_edges = entities.grep(Sketchup::Edge).select do |edge|
      faces = edge.faces
      next false if faces.size != 2
      normal1 = faces[0].normal
      normal2 = faces[1].normal
      normal1.parallel?(normal2) && (faces[0].plane[3] - faces[1].plane[3]).abs < 0.001
    end
    entities.erase_entities(coplanar_edges)

    model.commit_operation
    puts "Custom cleanup completed with coplanar edge removal."
  end

  UI.add_context_menu_handler do |menu|
    menu.add_item("Process Buildable Component") { self.activate }
  end
end
