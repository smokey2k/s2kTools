module Plugins
  module S2kTools
    @@selected_scene = nil

    #------------------------------
    # Move model to origin
    def self.move_model_to_origin
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        UI.messagebox("Please select a group or component containing the cube.")
        return
      end

      instance = selection.first
      unless instance.is_a?(Sketchup::Group) || instance.is_a?(Sketchup::ComponentInstance)
        UI.messagebox("Please select a valid group or component instance.")
        return
      end

      base_point = Geom::Point3d.new(0, 0, 0)
      transformation = instance.transformation
      base_point_transformed = base_point.transform(transformation)

      move_vector = Geom::Vector3d.new(
        ORIGIN.x - base_point_transformed.x,
        ORIGIN.y - base_point_transformed.y,
        ORIGIN.z - base_point_transformed.z
      )
      new_transformation = transformation * Geom::Transformation.translation(move_vector)

      instance.transformation = new_transformation

      # ✅ Move the camera to the selected scene if available
      if @@selected_scene
        pages = model.pages
        selected_page = pages[@@selected_scene]
        if selected_page
          pages.selected_page = selected_page
        else
          UI.messagebox("Selected scene not found. Component moved to origin.")
        end
      end
    end

    #------------------------------
    # Export view to PDF
    def self.export_view_to_pdf
      model = Sketchup.active_model

      if @@selected_scene
        pages = model.pages
        selected_page = pages[@@selected_scene]
        if selected_page
          pages.selected_page = selected_page
        else
          UI.messagebox("Selected scene not found. Using the default view.")
        end
      end

      selection = model.selection

      if selection.empty?
        UI.messagebox("Please select a group or component to define the filename.")
        return
      end

      instance = selection.first
      unless instance.is_a?(Sketchup::Group) || instance.is_a?(Sketchup::ComponentInstance)
        UI.messagebox("Please select a valid group or component instance.")
        return
      end

      # Replace spaces and newline characters in the name with underscores
      definition_name = instance.definition.name.to_s.gsub(/[\s\r\n]+/, '_').gsub(/[^\w\-]/, '')
      if definition_name.empty?
        definition_name = "Unnamed_Component"
      end

      selection.clear

      # Get the directory of the current model file
      model_path = model.path
      if model_path.empty?
        UI.messagebox("Please save your SketchUp model before exporting.")
        return
      end

      model_dir = File.dirname(model_path)
      pdf_dir = File.join(model_dir, "PDF")

      # Create the PDF directory if it doesn't exist
      FileUtils.mkdir_p(pdf_dir)

      file = File.join(pdf_dir, "#{definition_name}.pdf").gsub("\\", "/")

      options = {
        full_scale: true,
        show_summary: true,
        output_profile_lines: true,
        map_fonts: false,
        model_units: Length::Centimeter,
        line_weight: 0.3,
      }

      attempt = 0

      UI.start_timer(0.5, false) do
        success = model.export(file, options)
        if success
          UI.messagebox("Model exported as '#{file}'.")
        elsif attempt < 1
          attempt += 1
          UI.start_timer(0.5, false) do
            success = model.export(file, options)
            if success
              UI.messagebox("Model exported as '#{file}' (after retry).")
            else
              UI.messagebox("Export failed after retry. Try cleaning the component.")
            end
          end
        else
          UI.messagebox("Export failed. Try cleaning the component.")
        end
      end
    end

    #------------------------------
    # Configure selected scene
    def self.configure_extension
      model = Sketchup.active_model
      pages = model.pages
      scene_names = pages.map(&:name)

      if scene_names.empty?
        UI.messagebox("No scenes found in the model.")
        return
      end

      prompts = ["Select Scene"]
      defaults = [scene_names.first]
      list = [scene_names.join("|")]
      input = UI.inputbox(prompts, defaults, list, "Configure s2kTools")

      if input
        @@selected_scene = input.first
        UI.messagebox("Selected scene: #{@@selected_scene}")
      end
    end
  end
end
